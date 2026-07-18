import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../services/api_client.dart';
import '../config/central_auth_config.dart';
import '../network/api_config.dart';
import '../storage/local_storage.dart';
import 'auth_identifier_normalizer.dart';
import 'central_auth_api.dart';
import 'central_auth_error.dart';
import 'secure_storage_service.dart';

/// The 8 canonical auth states the data layer can be in. `unknown` and
/// `bootstrapFailed` are Furtail-specific (splash/retry handling on top of
/// the base Central Auth contract); the remaining 6 map directly onto
/// Central Auth API outcomes:
/// - [initial] is [unknown] renamed conceptually (kept as `unknown` for
///   source compat with existing `AuthGate`/tests — see [AuthStatus.unknown]).
/// - [requiresOtp]: an OTP was requested/is pending verification
///   (`/auth/otp/request` succeeded, or `/auth/otp/verify` hasn't run yet).
/// - [requiresProfileCompletion]: a provider/OTP login succeeded at the
///   Central Auth layer but the backend reported `NEEDS_PROFILE_COMPLETION`
///   (`requiredProfileFields` from bootstrap tells the UI what's missing).
/// - [requiresAccountLinking]: `/auth/identity/:provider` returned
///   `ACCOUNT_LINK_REQUIRED`/`ACCOUNT_CONFLICT` — an existing account was
///   matched but linking must be explicitly confirmed.
/// - [error]: a definitive, non-retryable failure surfaced to the UI as a
///   typed error rather than a state transition (see [AuthState.lastError]
///   plus [AuthState.typedError]).
enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  bootstrapFailed,
  requiresOtp,
  requiresProfileCompletion,
  requiresAccountLinking,
  error,
}

/// Context carried while [AuthStatus.requiresOtp] — which channel/recipient
/// an OTP was requested for, so the (not-yet-built) verify screen knows what
/// to resend/verify against.
class OtpChallenge {
  const OtpChallenge({required this.channel, required this.recipient});

  final String channel; // 'email' | 'phone' | 'whatsapp'
  final String recipient;
}

/// Context carried while [AuthStatus.requiresProfileCompletion] — which
/// fields the backend (via bootstrap's `requiredProfileFields`, or the
/// `NEEDS_PROFILE_COMPLETION` error itself) still needs before the session
/// is fully usable.
class ProfileCompletionChallenge {
  const ProfileCompletionChallenge({required this.requiredFields});

  final List<String> requiredFields;
}

/// Context carried while [AuthStatus.requiresAccountLinking] — the provider
/// whose token produced an `ACCOUNT_LINK_REQUIRED`/`ACCOUNT_CONFLICT`
/// response, so the (not-yet-built) link-confirmation screen can re-submit
/// the same provider token via `identityLink`.
class AccountLinkingChallenge {
  const AccountLinkingChallenge({
    required this.provider,
    this.idToken,
    this.accessToken,
  });

  final String provider;
  final String? idToken;
  final String? accessToken;
}

class AuthState {
  final AuthStatus status;
  final UserEntity? profile;
  final String? lastError;
  final CentralAuthError? typedError;
  final OtpChallenge? otpChallenge;
  final ProfileCompletionChallenge? profileCompletionChallenge;
  final AccountLinkingChallenge? accountLinkingChallenge;
  final CentralAuthBootstrap? bootstrap;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.profile,
    this.lastError,
    this.typedError,
    this.otpChallenge,
    this.profileCompletionChallenge,
    this.accountLinkingChallenge,
    this.bootstrap,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? profile,
    String? lastError,
    CentralAuthError? typedError,
    OtpChallenge? otpChallenge,
    ProfileCompletionChallenge? profileCompletionChallenge,
    AccountLinkingChallenge? accountLinkingChallenge,
    CentralAuthBootstrap? bootstrap,
  }) => AuthState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    lastError: lastError,
    typedError: typedError,
    otpChallenge: otpChallenge,
    profileCompletionChallenge: profileCompletionChallenge,
    accountLinkingChallenge: accountLinkingChallenge,
    bootstrap: bootstrap ?? this.bootstrap,
  );
}

/// Thrown when a Central Auth login succeeds (tokens are valid and saved)
/// but resolving the Central Auth identity to a local Furtail user via
/// `GET /api/v1/auth/me` fails — e.g. the Furtail API is unreachable, or
/// returns an identity conflict. Distinct from [CentralAuthException] so
/// the login screen never collapses "login worked, profile fetch didn't"
/// into a generic/invalid-credentials message.
class FurtailProfileException implements Exception {
  FurtailProfileException(
    this.message, {
    this.isNetworkError = false,
    this.statusCode,
  });

  final String message;
  final bool isNetworkError;
  final int? statusCode;

  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// Owns the native, in-app Central Auth session: REST login/registration,
/// bootstrap/session-restore, token refresh coordination, and logout. No
/// browser, Custom Tab, or WebView is ever involved — every network call
/// here is a direct JSON request to either the Central Auth API
/// ([CentralAuthApi]) or the Furtail API's own `/auth/me` (via
/// [ApiClient], which resolves the Central Auth identity to the local
/// Furtail user record).
class AuthController extends StateNotifier<AuthState> {
  final SecureStorageService _secureStorage;
  final CentralAuthApi _centralAuthApi;
  final ApiClient _apiClient;

  AuthController(this._secureStorage, this._centralAuthApi, this._apiClient)
    : super(const AuthState());

  /// The Furtail API's own profile-resolution endpoint — resolves the
  /// Central Auth bearer token to a local Furtail user (JIT-provisioning
  /// one if needed). This is a Furtail API path, never Central Auth's.
  ///
  /// MUST be a full absolute URL: [ApiClient] intentionally never sets a
  /// Dio `baseUrl` (every call site builds one from [ApiConfig] — see its
  /// class doc comment), so a bare `/api/v1/auth/me` here would resolve
  /// against no host at all and Dio would throw
  /// "No host specified in URI" instead of hitting the Furtail API.
  static String get _meUrl => '${ApiConfig.apiV1}/auth/me';

  Future<void> bootstrap() async {
    state = state.copyWith(status: AuthStatus.unknown);
    // Best-effort: fetch the Central Auth bootstrap payload (enabled login
    // methods/providers/OTP policy) so login/register screens can render
    // provider buttons from live data. Never blocks or fails the session
    // restore below — a failed fetch just leaves [AuthState.bootstrap] null
    // and screens fall back to "no providers available".
    unawaited(loadBootstrap());
    final hasSession = await _secureStorage.hasSession;
    if (!hasSession) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    await _migrateLegacyAudienceIfNeeded();
    try {
      final user = await _fetchProfile();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        profile: user,
        lastError: null,
        typedError: null,
      );
    } on ApiClientException catch (e) {
      final profileError = _messageForProfileError(e);
      state = _isRecoverableProfileError(e)
          ? state.copyWith(
              status: AuthStatus.authenticated,
              lastError: profileError.message,
            )
          : state.copyWith(
              status: AuthStatus.bootstrapFailed,
              lastError: profileError.message,
            );
    } on DioException catch (e) {
      final profileError = _messageForProfileError(e);
      state = _isRecoverableProfileError(e)
          ? state.copyWith(
              status: AuthStatus.authenticated,
              lastError: profileError.message,
            )
          : state.copyWith(
              status: AuthStatus.bootstrapFailed,
              lastError: profileError.message,
            );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.bootstrapFailed,
        lastError: e.toString(),
      );
    }
  }

  /// `GET /auth/bootstrap` — fetched independently of session restore so it
  /// is available on the login/register screens even when there is no
  /// signed-in user yet. Failures are swallowed: [AuthState.bootstrap]
  /// simply stays whatever it was (null on first run), and provider-grid UI
  /// must treat a null bootstrap as "nothing to show yet", never as an error.
  Future<void> loadBootstrap() async {
    try {
      final bootstrap = await _centralAuthApi.bootstrap();
      state = state.copyWith(bootstrap: bootstrap);
    } catch (_) {
      // Best-effort only; provider buttons just won't render this session.
    }
  }

  /// Sessions created before the app sent clientId carry Central Auth's
  /// default audience ("bpa-mobile"), which the Furtail API only accepts
  /// during the configured migration window. Refreshing with clientId
  /// re-issues furtail-mobile-audience tokens, so an eligible legacy session
  /// upgrades itself the next time the app starts. Best-effort: any failure
  /// leaves the session as-is for the normal 401/refresh path to handle.
  Future<void> _migrateLegacyAudienceIfNeeded() async {
    try {
      final accessToken = await _secureStorage.accessToken;
      if (accessToken == null) return;
      final aud = tokenAudience(accessToken);
      if (aud == null || aud == CentralAuthConfig.clientId) return;

      final refreshToken = await _secureStorage.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) return;
      final tokens = await _centralAuthApi.refreshToken(refreshToken);
      final newRefresh = tokens.refreshToken;
      await _secureStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: (newRefresh == null || newRefresh.isEmpty)
            ? refreshToken
            : newRefresh,
      );
    } catch (_) {
      // Best-effort only.
    }
  }

  /// Decodes the `aud` claim from a JWT without verifying it (verification
  /// is the server's job; this is only used to decide whether a proactive
  /// migration refresh is worthwhile). Returns null on any malformed input.
  @visibleForTesting
  static String? tokenAudience(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final aud = (payload as Map<String, dynamic>)['aud'];
      if (aud is String) return aud;
      if (aud is List && aud.isNotEmpty) return aud.first.toString();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<UserModel> _fetchProfile() async {
    final response = await _apiClient
        .get(_meUrl)
        .timeout(const Duration(seconds: 10));
    final body = response is Map<String, dynamic>
        ? response
        : (response is Map
              ? Map<String, dynamic>.from(response)
              : <String, dynamic>{});

    final Map<String, dynamic> userJson;
    if (body['user'] is Map) {
      userJson = Map<String, dynamic>.from(body['user'] as Map);
    } else if (body['data'] is Map) {
      userJson = Map<String, dynamic>.from(body['data'] as Map);
    } else {
      userJson = body;
    }
    final user = UserModel.fromJson(userJson);
    await _cacheDisplayInfo(user);
    return user;
  }

  FurtailProfileException _messageForProfileError(Object error) {
    final statusCode = _statusCodeFor(error);
    final isNetwork = _isNetworkError(error);
    if (isNetwork) {
      return FurtailProfileException(
        'Could not reach the Furtail service. Check your connection and try again.',
        isNetworkError: true,
      );
    }
    if (statusCode == 409) {
      final data = _responseDataFor(error);
      final message = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'This account is already linked to a different Furtail profile.';
      return FurtailProfileException(message, statusCode: 409);
    }
    if (statusCode != null && statusCode >= 500) {
      return FurtailProfileException(
        'The Furtail service is temporarily unavailable. Please try again shortly.',
        statusCode: statusCode,
      );
    }
    return FurtailProfileException(
      'Signed in, but your Furtail profile could not be loaded.',
      statusCode: statusCode,
    );
  }

  bool _isNetworkError(Object error) {
    if (error is ApiClientException) {
      return error.isNetworkError;
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
    }
    return false;
  }

  int? _statusCodeFor(Object error) {
    if (error is ApiClientException) return error.statusCode;
    if (error is DioException) return error.response?.statusCode;
    return null;
  }

  Object? _responseDataFor(Object error) {
    if (error is ApiClientException) return error.responseData;
    if (error is DioException) return error.response?.data;
    return null;
  }

  /// Keeps the legacy synchronous display-cache getters in [LocalStorage]
  /// (`getUserId`/`getAvatarUrl`, still read by several preserved domain
  /// screens) populated from the Furtail `/auth/me` response. Best-effort
  /// only — never blocks or fails authentication.
  Future<void> _cacheDisplayInfo(UserModel user) async {
    try {
      await LocalStorage.cacheUserDisplayInfo(
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        avatarUrl: user.avatarUrl,
      );
    } catch (_) {
      // Non-fatal: display cache is best-effort only.
    }
  }

  /// Native email/username/phone login against the Central Auth REST API —
  /// no browser involved. Returns normally on success; throws
  /// [CentralAuthException] or [BangladeshPhoneNormalizationException] on
  /// failure so the login screen can show a specific message.
  Future<void> login({
    required String identifier,
    required String password,
    required AuthIdentifierType identifierType,
  }) async {
    state = state.copyWith(lastError: null);
    final result = await _loginWithMobileFallback(
      identifier: identifier,
      password: password,
      identifierType: identifierType,
    );
    final refreshToken = result.tokens.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Central Auth login did not return a refresh token.');
    }
    await _secureStorage.saveTokens(
      accessToken: result.tokens.accessToken,
      refreshToken: refreshToken,
    );
    if (kDebugMode) {
      final savedAccessToken = await _secureStorage.accessToken;
      developer.log(
        'tokenSaved=${savedAccessToken != null} '
        'interceptorCanReadToken=${savedAccessToken != null}',
        name: 'AuthController',
      );
    }

    // Central Auth login has now genuinely succeeded (tokens are valid and
    // persisted) — a failure past this point is a *separate* concern
    // (resolving the identity to a local Furtail user) and must not be
    // reported as "invalid credentials" or a generic login failure.
    await _resolveProfileAfterSession();
  }

  /// Completes a social/web-provider login performed via the system browser
  /// (flutter_web_auth_2): the Central Auth social callback returns tokens
  /// in the redirect-URI fragment; this persists them and resolves the
  /// Furtail profile exactly like [login]. Throws [FurtailProfileException]
  /// on a non-recoverable profile failure, same as [login].
  Future<void> completeSocialLogin({
    required String accessToken,
    required String refreshToken,
  }) async {
    state = state.copyWith(lastError: null);
    await _secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _resolveProfileAfterSession();
  }

  /// Shared post-session transition: fetch the Furtail profile and move to
  /// [AuthStatus.authenticated] (or the appropriate failure state). Assumes
  /// valid Central Auth tokens are already persisted.
  Future<void> _resolveProfileAfterSession() async {
    try {
      final user = await _fetchProfile();
      state = AuthState(status: AuthStatus.authenticated, profile: user);
    } on ApiClientException catch (e) {
      final furtailError = _messageForProfileError(e);
      if (_isRecoverableProfileError(e)) {
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: null,
          lastError: furtailError.message,
        );
      } else {
        state = AuthState(
          status: AuthStatus.bootstrapFailed,
          lastError: furtailError.message,
        );
        throw furtailError;
      }
    } on DioException catch (e) {
      final furtailError = _messageForProfileError(e);
      if (_isRecoverableProfileError(e)) {
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: null,
          lastError: furtailError.message,
        );
      } else {
        state = AuthState(
          status: AuthStatus.bootstrapFailed,
          lastError: furtailError.message,
        );
        throw furtailError;
      }
    } catch (e) {
      final furtailError = FurtailProfileException(
        'Failed to load your profile data from the service. Please try logging in again.',
      );
      state = AuthState(
        status: AuthStatus.bootstrapFailed,
        lastError: furtailError.message,
      );
      throw furtailError;
    }
  }

  bool _isRecoverableProfileError(Object error) {
    if (error is ApiClientException) {
      return error.isNetworkError ||
          (error.statusCode != null && error.statusCode! >= 500);
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          (error.response?.statusCode != null &&
              error.response!.statusCode! >= 500);
    }
    return false;
  }

  /// Some Central Auth accounts were created before the canonical local
  /// (`01XXXXXXXXXX`) phone format was enforced and are still stored as
  /// `+880XXXXXXXXXX`. On a confirmed INVALID_CREDENTIALS 401 for a mobile
  /// identifier only, retry once with that legacy format — mirrors BPA
  /// User App's login fallback exactly.
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})>
  _loginWithMobileFallback({
    required String identifier,
    required String password,
    required AuthIdentifierType identifierType,
  }) async {
    try {
      return await _centralAuthApi.login(
        identifier: identifier,
        password: password,
      );
    } on CentralAuthException catch (e) {
      final isMobile = identifierType == AuthIdentifierType.mobile;
      final isInvalidCredentials =
          e.isUnauthorized && e.code == 'INVALID_CREDENTIALS';
      if (!isMobile || !isInvalidCredentials) rethrow;

      final alternate = AuthIdentifierNormalizer.toAlternateBangladeshPhone(
        identifier,
      );
      return _centralAuthApi.login(identifier: alternate, password: password);
    }
  }

  /// Registers the account. The backend does not return a session on
  /// register, so the caller must send the user to the login screen next.
  Future<void> register({
    required String displayName,
    String? phone,
    String? email,
    required String password,
  }) {
    return _centralAuthApi.register(
      displayName: displayName,
      phone: phone,
      email: email,
      password: password,
    );
  }

  Future<void> requestPasswordReset({required String email}) {
    return _centralAuthApi.forgotPassword(
      email: email,
      clientId: CentralAuthConfig.clientId,
    );
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) {
    return _centralAuthApi.resetPassword(token: token, password: password);
  }

  /// `POST /auth/otp/request` — transitions to [AuthStatus.requiresOtp] on
  /// success so a (not-yet-built) OTP-entry screen can render. Data-layer
  /// only: no UI is built by this method.
  Future<void> requestOtp({
    required String channel,
    required String recipient,
  }) async {
    try {
      await _centralAuthApi.requestOtp(channel: channel, recipient: recipient);
      state = AuthState(
        status: AuthStatus.requiresOtp,
        otpChallenge: OtpChallenge(channel: channel, recipient: recipient),
      );
    } on CentralAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        lastError: e.message,
        typedError: e.typed,
      );
      rethrow;
    }
  }

  /// `POST /auth/otp/verify` — completes an OTP login started by
  /// [requestOtp] and saves the returned session, same as [login].
  Future<void> verifyOtp({
    required String channel,
    required String recipient,
    required String code,
  }) async {
    try {
      final result = await _centralAuthApi.verifyOtp(
        channel: channel,
        recipient: recipient,
        code: code,
      );
      await _saveSessionAndResolveProfile(result.tokens);
    } on CentralAuthException catch (e) {
      if (e.typed is CentralAuthNeedsProfileCompletion) {
        state = AuthState(
          status: AuthStatus.requiresProfileCompletion,
          profileCompletionChallenge: const ProfileCompletionChallenge(
            requiredFields: [],
          ),
        );
        return;
      }
      state = AuthState(
        status: AuthStatus.error,
        lastError: e.message,
        typedError: e.typed,
      );
      rethrow;
    }
  }

  /// Exchanges a provider token (obtained natively by a provider adapter —
  /// never a browser/WebView) for a Central Auth session via
  /// `POST /auth/identity/:provider`. Handles the account-linking and
  /// profile-completion branches by transitioning state instead of throwing
  /// a generic error, so the (not-yet-built) UI can react appropriately.
  Future<void> loginWithProvider({
    required String provider,
    String? idToken,
    String? accessToken,
    String? nonce,
    String? orgSlug,
  }) async {
    try {
      final result = await _centralAuthApi.identityLogin(
        provider: provider,
        idToken: idToken,
        accessToken: accessToken,
        nonce: nonce,
        orgSlug: orgSlug,
      );
      await _saveSessionAndResolveProfile(result.tokens);
    } on CentralAuthException catch (e) {
      final typed = e.typed;
      if (typed is CentralAuthAccountLinkRequired ||
          typed is CentralAuthIdentityConflict) {
        state = AuthState(
          status: AuthStatus.requiresAccountLinking,
          accountLinkingChallenge: AccountLinkingChallenge(
            provider: provider,
            idToken: idToken,
            accessToken: accessToken,
          ),
        );
        return;
      }
      if (typed is CentralAuthNeedsProfileCompletion) {
        state = AuthState(
          status: AuthStatus.requiresProfileCompletion,
          profileCompletionChallenge: const ProfileCompletionChallenge(
            requiredFields: [],
          ),
        );
        return;
      }
      state = AuthState(
        status: AuthStatus.error,
        lastError: e.message,
        typedError: typed,
      );
      rethrow;
    }
  }

  /// `POST /auth/identity/:provider/link` — links an additional provider to
  /// the currently-authenticated user (requires an existing session).
  Future<void> linkProvider({
    required String provider,
    String? idToken,
    String? accessToken,
    String? nonce,
    String? orgSlug,
  }) async {
    final token = await _secureStorage.accessToken;
    if (token == null) {
      throw StateError('linkProvider requires an authenticated session.');
    }
    await _centralAuthApi.identityLink(
      accessToken: token,
      provider: provider,
      idToken: idToken,
      providerAccessToken: accessToken,
      nonce: nonce,
      orgSlug: orgSlug,
    );
  }

  Future<void> _saveSessionAndResolveProfile(
    CentralAuthTokenResult tokens,
  ) async {
    final refreshToken = tokens.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Central Auth login did not return a refresh token.');
    }
    await _secureStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: refreshToken,
    );
    try {
      final user = await _fetchProfile();
      state = AuthState(status: AuthStatus.authenticated, profile: user);
    } catch (e) {
      final furtailError = _messageForProfileError(e);
      if (_isRecoverableProfileError(e)) {
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: null,
          lastError: furtailError.message,
        );
      } else {
        state = AuthState(
          status: AuthStatus.bootstrapFailed,
          lastError: furtailError.message,
        );
        throw furtailError;
      }
    }
  }

  Future<void> logout() async {
    final accessToken = await _secureStorage.accessToken;
    final refreshToken = await _secureStorage.refreshToken;
    await _secureStorage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
    if (accessToken != null) {
      try {
        await _centralAuthApi.logout(accessToken, refreshToken: refreshToken);
      } catch (_) {
        // Ignore network failures on logout; local session is cleared regardless.
      }
    }
  }

  /// Invoked by [AuthInterceptor] when a refresh attempt fails (401/403 on
  /// a Furtail API call that couldn't be recovered).
  void forceLogout() {
    unawaited(_secureStorage.clear());
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      ref.read(secureStorageServiceProvider),
      ref.read(centralAuthApiProvider),
      ref.read(apiClientProvider),
    );
  },
);
