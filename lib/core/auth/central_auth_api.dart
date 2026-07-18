import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/central_auth_config.dart';
import 'central_auth_error.dart';

/// `GET /auth/bootstrap` response (`data` payload) — tells the UI which
/// login methods/providers are enabled so screens can decide what to render.
/// Mirrors the exact shape returned by `bootstrap.service.ts`.
class CentralAuthBootstrap {
  const CentralAuthBootstrap({
    required this.registrationOpen,
    required this.requiredProfileFields,
    required this.loginMethods,
    required this.providers,
    required this.enterpriseOrganizations,
    this.enterpriseOrgDetails = const [],
    required this.otpCodeLength,
    required this.otpExpiryMinutes,
    required this.otpResendCooldownSeconds,
    this.passwordPolicy,
  });

  final bool registrationOpen;
  final List<String> requiredProfileFields;
  final CentralAuthLoginMethods loginMethods;
  final List<CentralAuthProvider> providers;

  /// Enterprise orgs as reported by bootstrap. Slugs only, kept for
  /// backward compatibility; [enterpriseOrgDetails] carries the protocol.
  final List<String> enterpriseOrganizations;
  final List<CentralAuthEnterpriseOrg> enterpriseOrgDetails;
  final int? otpCodeLength;
  final int? otpExpiryMinutes;
  final int? otpResendCooldownSeconds;
  final CentralAuthPasswordPolicy? passwordPolicy;

  factory CentralAuthBootstrap.fromJson(Map<String, dynamic> json) {
    final loginMethodsJson =
        (json['loginMethods'] as Map?)?.cast<String, dynamic>() ?? const {};
    final providersJson = (json['providers'] as List?) ?? const [];
    final enterpriseJson =
        (json['enterpriseOrganizations'] as List?) ?? const [];
    final otpJson = (json['otp'] as Map?)?.cast<String, dynamic>();
    final passwordPolicyJson = (json['passwordPolicy'] as Map?)
        ?.cast<String, dynamic>();
    return CentralAuthBootstrap(
      registrationOpen: json['registrationOpen'] as bool? ?? true,
      requiredProfileFields:
          (json['requiredProfileFields'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      loginMethods: CentralAuthLoginMethods.fromJson(loginMethodsJson),
      providers: providersJson
          .map(
            (e) => CentralAuthProvider.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      enterpriseOrganizations: enterpriseJson
          .map(
            (e) => (e is Map ? e['orgSlug']?.toString() : e.toString()) ?? '',
          )
          .where((s) => s.isNotEmpty)
          .toList(),
      enterpriseOrgDetails: enterpriseJson
          .whereType<Map>()
          .map(
            (e) => CentralAuthEnterpriseOrg(
              orgSlug: e['orgSlug']?.toString() ?? '',
              displayName:
                  e['displayName']?.toString() ??
                  e['orgSlug']?.toString() ??
                  '',
              protocol: e['protocol']?.toString().toUpperCase() ?? 'OIDC',
            ),
          )
          .where((o) => o.orgSlug.isNotEmpty)
          .toList(),
      otpCodeLength: otpJson?['codeLength'] as int?,
      otpExpiryMinutes: otpJson?['expiryMinutes'] as int?,
      otpResendCooldownSeconds: otpJson?['resendCooldownSeconds'] as int?,
      passwordPolicy: passwordPolicyJson != null
          ? CentralAuthPasswordPolicy.fromJson(passwordPolicyJson)
          : null,
    );
  }
}

/// One enterprise organization from `bootstrap.enterpriseOrganizations`.
/// Only `protocol == 'OIDC'` orgs are wired to the system-browser flow;
/// SAML orgs render disabled (the server also refuses them with
/// ENTERPRISE_PROVIDER_UNSUPPORTED — no fake SAML support).
class CentralAuthEnterpriseOrg {
  const CentralAuthEnterpriseOrg({
    required this.orgSlug,
    required this.displayName,
    required this.protocol,
  });

  final String orgSlug;
  final String displayName;
  final String protocol;

  bool get isOidc => protocol == 'OIDC';
}

/// `bootstrap.passwordPolicy` — mirrors `PASSWORD_POLICY` in
/// `wpa_auth_api/src/modules/auth/bootstrap.service.ts`. Used by the reset/
/// set-password screens to render live policy hints instead of a hardcoded
/// "at least 8 characters" string.
class CentralAuthPasswordPolicy {
  const CentralAuthPasswordPolicy({
    required this.minLength,
    required this.requiresUppercase,
    required this.requiresNumber,
    required this.requiresSymbol,
  });

  final int minLength;
  final bool requiresUppercase;
  final bool requiresNumber;
  final bool requiresSymbol;

  factory CentralAuthPasswordPolicy.fromJson(Map<String, dynamic> json) {
    return CentralAuthPasswordPolicy(
      minLength: json['minLength'] as int? ?? 8,
      requiresUppercase: json['requiresUppercase'] as bool? ?? false,
      requiresNumber: json['requiresNumber'] as bool? ?? false,
      requiresSymbol: json['requiresSymbol'] as bool? ?? false,
    );
  }

  /// Returns the reasons [password] fails this policy (empty = passes).
  List<String> violations(String password) {
    final issues = <String>[];
    if (password.length < minLength) issues.add('minLength');
    if (requiresUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      issues.add('uppercase');
    }
    if (requiresNumber && !password.contains(RegExp(r'[0-9]'))) {
      issues.add('number');
    }
    if (requiresSymbol &&
        !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/;~`+=]'))) {
      issues.add('symbol');
    }
    return issues;
  }
}

class CentralAuthLoginMethods {
  const CentralAuthLoginMethods({
    required this.emailPassword,
    required this.phonePassword,
    required this.emailOtp,
    required this.phoneOtp,
    required this.whatsappOtp,
  });

  final bool emailPassword;
  final bool phonePassword;
  final bool emailOtp;
  final bool phoneOtp;
  final bool whatsappOtp;

  factory CentralAuthLoginMethods.fromJson(Map<String, dynamic> json) {
    return CentralAuthLoginMethods(
      emailPassword: json['emailPassword'] as bool? ?? false,
      phonePassword: json['phonePassword'] as bool? ?? false,
      emailOtp: json['emailOtp'] as bool? ?? false,
      phoneOtp: json['phoneOtp'] as bool? ?? false,
      whatsappOtp: json['whatsappOtp'] as bool? ?? false,
    );
  }
}

class CentralAuthProvider {
  const CentralAuthProvider({
    required this.id,
    required this.displayName,
    required this.enabled,
  });

  final String id;
  final String displayName;
  final bool enabled;

  factory CentralAuthProvider.fromJson(Map<String, dynamic> json) {
    return CentralAuthProvider(
      id: json['id'].toString(),
      displayName: json['displayName']?.toString() ?? json['id'].toString(),
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

/// One row of `GET /auth/sessions` — mirrors `listMyActiveSessions` in
/// `auth.service.ts` exactly (`id`, `isCurrent`, `client.name`, `userAgent`,
/// `ipAddress`, `country`, `lastActiveAt`/`createdAt`/`expiresAt`). No field
/// is invented beyond what that endpoint actually returns.
class CentralAuthSession {
  const CentralAuthSession({
    required this.id,
    required this.isCurrent,
    this.clientName,
    this.userAgent,
    this.ipAddress,
    this.country,
    this.lastActiveAt,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final bool isCurrent;
  final String? clientName;
  final String? userAgent;
  final String? ipAddress;
  final String? country;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory CentralAuthSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v is String ? DateTime.tryParse(v) : null;
    final client = (json['client'] as Map?)?.cast<String, dynamic>();
    return CentralAuthSession(
      id: json['id'].toString(),
      isCurrent: json['isCurrent'] as bool? ?? false,
      clientName: client?['name']?.toString(),
      userAgent: json['userAgent'] as String?,
      ipAddress: json['ipAddress'] as String?,
      country: json['country'] as String?,
      lastActiveAt: parseDate(json['lastActiveAt']),
      createdAt: parseDate(json['createdAt']),
      expiresAt: parseDate(json['expiresAt']),
    );
  }
}

class CentralAuthTokenResult {
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;

  CentralAuthTokenResult({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  factory CentralAuthTokenResult.fromJson(Map<String, dynamic> json) {
    return CentralAuthTokenResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresIn: json['expiresIn'] as int?,
    );
  }
}

/// Mirrors the Central Auth API's `SafeUser` shape returned under a `user`
/// key by `/auth/login` and `/auth/register`.
class CentralAuthUser {
  final String id;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? username;

  CentralAuthUser({
    required this.id,
    this.displayName,
    this.email,
    this.phone,
    this.username,
  });

  factory CentralAuthUser.fromJson(Map<String, dynamic> json) {
    return CentralAuthUser(
      id: json['id'].toString(),
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      username: json['username'] as String?,
    );
  }
}

/// Thrown for Central Auth API errors, carrying the HTTP status and the
/// backend's error `code` (e.g. `INVALID_CREDENTIALS`) so callers can show
/// distinct messages instead of a single generic failure string.
class CentralAuthException implements Exception {
  CentralAuthException({
    required this.message,
    this.statusCode,
    this.code,
    this.dioExceptionType,
    this.details,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final String? dioExceptionType;

  /// Raw `details`/extra fields from the error body (e.g.
  /// `{ retryAfterSeconds: 42 }` on `OTP_RESEND_COOLDOWN`). Prefer [typed]'s
  /// dedicated fields over reading this map directly where one exists.
  final Map<String, dynamic>? details;

  String? get normalizedCode => code?.trim().toUpperCase();

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403 || normalizedCode == 'FORBIDDEN';
  bool get isNetworkError =>
      dioExceptionType == 'connectionError' ||
      dioExceptionType == 'connectionTimeout' ||
      dioExceptionType == 'receiveTimeout' ||
      dioExceptionType == 'sendTimeout';
  bool get isIdentityConflict => normalizedCode == 'IDENTITY_CONFLICT';
  bool get isTokenRevoked => normalizedCode == 'TOKEN_REVOKED';
  bool get isRefreshTokenExpired => normalizedCode == 'REFRESH_TOKEN_EXPIRED';
  bool get isCentralTokenExpired => normalizedCode == 'CENTRAL_TOKEN_EXPIRED';
  bool get isCentralTokenInvalid => normalizedCode == 'CENTRAL_TOKEN_INVALID';
  bool get isDefinitiveSessionFailure =>
      isTokenRevoked || isRefreshTokenExpired || isCentralTokenInvalid;

  /// Typed mapping of [code]/[statusCode] into [CentralAuthError] — prefer
  /// matching on this over the raw string getters above in new call sites.
  CentralAuthError get typed {
    if (isNetworkError) return CentralAuthNetworkError(message);
    return CentralAuthError.fromCode(
      code: normalizedCode,
      statusCode: statusCode,
      message: message,
      details: details,
    );
  }

  @override
  String toString() => message;
}

/// Talks directly to the Central Auth REST API (wpa_auth_api) for native
/// in-app login, registration, token refresh, and password reset. No
/// browser, Custom Tab, or WebView is ever launched — every call here is a
/// plain JSON HTTP request.
///
/// Uses a plain [Dio] instance that is NOT the interceptor-equipped app
/// [ApiClient] — attaching Furtail's AuthInterceptor here would create a
/// circular dependency (the interceptor calls back into this class to
/// refresh).
class CentralAuthApi {
  final Dio _dio;

  CentralAuthApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: CentralAuthConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  /// Test-only: inject a Dio with a fake adapter so request payloads (e.g.
  /// the mandatory clientId on session-issuing calls) can be asserted.
  @visibleForTesting
  CentralAuthApi.withDio(this._dio);

  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'emailOrUsername': identifier,
          'password': password,
          // Without the clientId, Central Auth signs the token with its
          // global default audience ("bpa-mobile"), which the Furtail API
          // then rejects as CENTRAL_TOKEN_INVALID — the exact cause of the
          // "profile could not be loaded" failure after a successful login.
          'clientId': CentralAuthConfig.clientId,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return (
        tokens: CentralAuthTokenResult.fromJson(body),
        user: CentralAuthUser.fromJson(body['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<CentralAuthUser> register({
    required String displayName,
    String? phone,
    String? email,
    String? username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'displayName': displayName,
          'password': password,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
          if (username != null && username.isNotEmpty) 'username': username,
          'clientId': CentralAuthConfig.clientId,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return CentralAuthUser.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<CentralAuthTokenResult> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {
          'refreshToken': refreshToken,
          // Lets a legacy session (created before the app sent clientId,
          // token audience "bpa-mobile") migrate to the furtail-mobile
          // audience on this rotation — see Central Auth refreshTokens.
          'clientId': CentralAuthConfig.clientId,
        },
      );
      return CentralAuthTokenResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<void> logout(String accessToken, {String? refreshToken}) async {
    try {
      final body = <String, dynamic>{};
      if (refreshToken != null) body['refreshToken'] = refreshToken;
      await _dio.post(
        '/auth/logout',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// Best-effort revoke used by [logout]-adjacent cleanup paths. Failures
  /// are swallowed by callers — local session clearing always proceeds.
  Future<void> revoke(String accessToken) async {
    try {
      await logout(accessToken);
    } catch (_) {
      // Best-effort; local session is already cleared by the caller.
    }
  }

  /// Requests a password-reset email. `POST /auth/forgot-password` takes an
  /// `email` (not a phone number) and always responds 200 regardless of
  /// whether the email is registered (so it can't be used to enumerate
  /// accounts).
  Future<void> forgotPassword({required String email, String? clientId}) async {
    try {
      await _dio.post(
        '/auth/forgot-password',
        data: {
          'email': email,
          // Sending clientId lets the auth server deep-link the reset email
          // back into this app instead of the admin panel.
          if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
        },
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// Completes a password reset using the opaque `token` from the emailed
  /// reset link. No session is returned; the user must log in again.
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      await _dio.post(
        '/auth/reset-password',
        data: {'token': token, 'password': password},
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `GET /auth/bootstrap` — enabled providers/login methods/OTP policy for
  /// the current client. Never throws for "no client configured"; the
  /// backend defaults to a permissive config in that case.
  Future<CentralAuthBootstrap> bootstrap({String? clientId}) async {
    try {
      final response = await _dio.get(
        '/auth/bootstrap',
        queryParameters: clientId != null ? {'clientId': clientId} : null,
      );
      final body = response.data as Map<String, dynamic>;
      final data = (body['data'] as Map).cast<String, dynamic>();
      return CentralAuthBootstrap.fromJson(data);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /auth/otp/request` — `channel` is `email`, `phone`, or
  /// `whatsapp`; `recipient` is the corresponding address/number.
  Future<void> requestOtp({
    required String channel,
    required String recipient,
  }) async {
    try {
      await _dio.post(
        '/auth/otp/request',
        data: {
          'channel': channel,
          'recipient': recipient,
          'clientId': CentralAuthConfig.clientId,
        },
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /auth/otp/verify` — `channel` is `email` or `phone` only (no
  /// `whatsapp`, per the backend schema). Returns a full session + user on
  /// success, same shape as [login].
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})> verifyOtp({
    required String channel,
    required String recipient,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/otp/verify',
        data: {
          'channel': channel,
          'recipient': recipient,
          'code': code,
          // Ensures the OTP session token is signed with the Furtail
          // audience — same reason as [login].
          'clientId': CentralAuthConfig.clientId,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return (
        tokens: CentralAuthTokenResult.fromJson(body),
        user: CentralAuthUser.fromJson(body['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /auth/login/phone` — phone + password login (distinct from the
  /// generic `/auth/login` which matches `emailOrUsername` against
  /// username/email/phone all at once).
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})> loginPhone({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login/phone',
        data: {
          'phone': phone,
          'password': password,
          'clientId': CentralAuthConfig.clientId,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return (
        tokens: CentralAuthTokenResult.fromJson(body),
        user: CentralAuthUser.fromJson(body['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /auth/identity/:provider` — exchanges a verified provider token
  /// (Google idToken, Facebook accessToken, Apple/Microsoft idToken, or an
  /// enterprise OIDC idToken with `orgSlug` as `org`) for a Central Auth
  /// session. Never used with a browser/WebView — the provider token is
  /// obtained natively by a provider adapter before this call.
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})>
  identityLogin({
    required String provider,
    String? idToken,
    String? accessToken,
    String? nonce,
    String? orgSlug,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/identity/$provider',
        queryParameters: orgSlug != null ? {'org': orgSlug} : null,
        data: {
          if (idToken != null) 'idToken': idToken,
          if (accessToken != null) 'accessToken': accessToken,
          if (nonce != null) 'nonce': nonce,
          'clientId': CentralAuthConfig.clientId,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return (
        tokens: CentralAuthTokenResult.fromJson(body),
        user: CentralAuthUser.fromJson(body['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /auth/identity/:provider/link` — links an additional provider to
  /// the currently-authenticated user. Requires a bearer access token.
  Future<void> identityLink({
    required String accessToken,
    required String provider,
    String? idToken,
    String? providerAccessToken,
    String? nonce,
    String? orgSlug,
  }) async {
    try {
      await _dio.post(
        '/auth/identity/$provider/link',
        queryParameters: orgSlug != null ? {'org': orgSlug} : null,
        data: {
          if (idToken != null) 'idToken': idToken,
          if (providerAccessToken != null) 'accessToken': providerAccessToken,
          if (nonce != null) 'nonce': nonce,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /auth/password/set` — sets a password for a social/OIDC-only
  /// account that has none yet. Requires a bearer access token.
  Future<void> setPassword({
    required String accessToken,
    required String password,
  }) async {
    try {
      await _dio.post(
        '/auth/password/set',
        data: {'password': password},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// Builds the system-browser OAuth start URL for a social provider.
  /// `app_client_id` attributes the session to this app's AuthClient (so the
  /// token is signed with the Furtail audience); `redirect_uri` is the
  /// registered custom scheme; `state`/`code_challenge` bind the callback to
  /// this attempt — the callback returns only a single-use code, never
  /// tokens.
  static Uri socialStartUrl(
    String providerId, {
    String? state,
    String? codeChallenge,
  }) {
    return Uri.parse(
      '${CentralAuthConfig.apiBaseUrl}/auth/social/$providerId/start',
    ).replace(
      queryParameters: {
        'app_client_id': CentralAuthConfig.clientId,
        'redirect_uri': CentralAuthConfig.oauthCallbackUri,
        if (state != null) 'state': state,
        if (codeChallenge != null) ...{
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      },
    );
  }

  /// Builds the system-browser OIDC start URL for an enterprise org —
  /// identical contract to [socialStartUrl] (code + PKCE completion).
  static Uri enterpriseStartUrl(
    String orgSlug, {
    String? state,
    String? codeChallenge,
  }) {
    return Uri.parse(
      '${CentralAuthConfig.apiBaseUrl}/auth/enterprise/$orgSlug/start',
    ).replace(
      queryParameters: {
        'app_client_id': CentralAuthConfig.clientId,
        'redirect_uri': CentralAuthConfig.oauthCallbackUri,
        if (state != null) 'state': state,
        if (codeChallenge != null) ...{
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      },
    );
  }

  /// `POST /auth/social/mobile/token` — exchanges the single-use
  /// authorization code from the mobile callback for session tokens, proving
  /// possession of the PKCE code verifier generated before the flow started.
  Future<CentralAuthTokenResult> exchangeMobileCode({
    required String code,
    required String codeVerifier,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/social/mobile/token',
        data: {
          'code': code,
          'codeVerifier': codeVerifier,
          'clientId': CentralAuthConfig.clientId,
          'redirectUri': CentralAuthConfig.oauthCallbackUri,
        },
      );
      return CentralAuthTokenResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `GET /auth/me` on the Central Auth API itself (distinct from Furtail's
  /// own `/api/v1/auth/me` profile-resolution endpoint used elsewhere).
  Future<CentralAuthUser> me(String accessToken) async {
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data as Map<String, dynamic>;
      return CentralAuthUser.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /auth/sessions/logout-others` — revokes every other active
  /// session/device but keeps the caller's current one alive (distinct from
  /// [logout], which ends the current session).
  Future<void> logoutAllOtherDevices(String accessToken) async {
    try {
      await _dio.post(
        '/auth/sessions/logout-others',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `GET /auth/sessions` — every currently-active (non-revoked, non-expired)
  /// login session for the authenticated user, across all devices. A real,
  /// confirmed endpoint (`auth.routes.ts` `router.get('/sessions', ...)` →
  /// `authService.listMyActiveSessions`) — this is a genuine multi-device
  /// list, not a single-device stand-in.
  Future<List<CentralAuthSession>> listSessions(String accessToken) async {
    try {
      final response = await _dio.get(
        '/auth/sessions',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data as Map<String, dynamic>;
      final sessions = (body['sessions'] as List?) ?? const [];
      return sessions
          .map(
            (e) =>
                CentralAuthSession.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `DELETE /auth/sessions/:sessionId` — revokes one specific session (e.g.
  /// a device other than the caller's own, or a stale one) by id.
  Future<void> revokeSession(String accessToken, String sessionId) async {
    try {
      await _dio.delete(
        '/auth/sessions/$sessionId',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  CentralAuthException _toException(DioException e) {
    final data = e.response?.data;
    String message = e.message ?? 'Network error';
    String? code;
    Map<String, dynamic>? details;
    // wpa_auth_api's errorHandler returns a flat
    // `{success: false, message, code}` body (see src/middleware/error.ts) —
    // as of this pass, the handler does NOT forward the AppError `details`
    // field (e.g. OTP_RESEND_COOLDOWN's `retryAfterSeconds`) to the response
    // body at all, so `details` below is always null today. Parsed anyway,
    // forward-compatibly, in case the backend starts including it — never
    // fabricate a value when it's absent.
    if (data is Map) {
      if (data['message'] != null) message = data['message'].toString();
      code = data['code']?.toString();
      if (data['details'] is Map) {
        details = (data['details'] as Map).cast<String, dynamic>();
      }
    }
    return CentralAuthException(
      message: message,
      statusCode: e.response?.statusCode,
      code: code,
      dioExceptionType: e.type.name,
      details: details,
    );
  }
}

final centralAuthApiProvider = Provider<CentralAuthApi>(
  (ref) => CentralAuthApi(),
);
