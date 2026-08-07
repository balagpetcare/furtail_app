import 'dart:async';

import 'central_auth_api.dart';
import 'secure_storage_service.dart';

/// Friendly, non-technical error shown to the UI after a session-recovery
/// attempt fails outright. Never wraps or forwards a raw backend message
/// (e.g. "Invalid or expired access token.") — those are logged, not shown.
class SessionRecoveryException implements Exception {
  const SessionRecoveryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The one shared single-flight session recovery flow for the whole app.
///
/// Both [AuthInterceptor] (for Dio calls routed through Furtail's API,
/// which surfaces its own `CENTRAL_TOKEN_EXPIRED` code after independently
/// verifying the JWT) and any code that talks to Central Auth directly
/// (`CentralAuthApi`, which has no interceptor of its own to avoid a
/// circular refresh dependency) must go through this single instance, so
/// that:
///   - only one refresh is ever in flight at a time, no matter how many
///     callers hit an expired token concurrently;
///   - every caller sees the same rotated token immediately after a
///     refresh, instead of racing on stale tokens;
///   - a definitive refresh failure clears the session and notifies the
///     app exactly once, instead of once per failing call site.
class SessionRecovery {
  SessionRecovery._({SecureStorageService? secureStorage, CentralAuthApi? centralAuthApi})
    : secureStorage = secureStorage ?? SecureStorageService(),
      centralAuthApi = centralAuthApi ?? CentralAuthApi();

  /// Process-wide instance. Tests may construct their own via
  /// [SessionRecovery.test] instead of touching this singleton.
  static SessionRecovery instance = SessionRecovery._();

  /// Test-only: an isolated instance with injected fakes, so concurrent
  /// test runs never share single-flight state with each other or with
  /// [instance].
  factory SessionRecovery.test({
    required SecureStorageService secureStorage,
    required CentralAuthApi centralAuthApi,
  }) = SessionRecovery._;

  final SecureStorageService secureStorage;
  final CentralAuthApi centralAuthApi;

  /// Wired once at app startup (see `apiClientProvider`). Fires exactly
  /// once per definitive session failure, however many concurrent callers
  /// triggered it.
  void Function() onSessionExpired = () {};

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  /// Refreshes the access token exactly once for any number of concurrent
  /// callers (mutex via a shared [Completer]). Returns the new access
  /// token, or null if refresh failed. On a definitive failure (rotated
  /// refresh token missing, refresh token expired/revoked, or the refresh
  /// call itself returns 401), clears the session and fires
  /// [onSessionExpired] — but only for the caller that actually performed
  /// the refresh, never once per waiter.
  Future<String?> refresh() async {
    if (_isRefreshing) {
      return _refreshCompleter?.future;
    }

    _isRefreshing = true;
    final completer = Completer<String?>();
    _refreshCompleter = completer;
    var shouldLogout = false;
    String? newAccessToken;
    try {
      final refreshToken = await secureStorage.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        shouldLogout = true;
        return null;
      }

      final result = await centralAuthApi.refreshToken(refreshToken);
      final rotatedRefreshToken = result.refreshToken;
      if (rotatedRefreshToken == null || rotatedRefreshToken.isEmpty) {
        shouldLogout = true;
        return null;
      }

      try {
        await secureStorage.saveTokens(
          accessToken: result.accessToken,
          refreshToken: rotatedRefreshToken,
        );
      } catch (_) {
        shouldLogout = true;
        return null;
      }

      newAccessToken = result.accessToken;
      return newAccessToken;
    } on CentralAuthException catch (e) {
      shouldLogout = e.isDefinitiveSessionFailure || e.isUnauthorized;
      return null;
    } catch (_) {
      return null;
    } finally {
      completer.complete(newAccessToken);
      _isRefreshing = false;
      _refreshCompleter = null;
      if (shouldLogout) {
        await secureStorage.clear();
        onSessionExpired();
      }
    }
  }

  /// Runs [action] with the current access token. If it throws and
  /// [isSessionExpired] matches, performs a single-flight [refresh] and
  /// retries [action] exactly once with the new token. Never resends the
  /// same expired token. On a definitive refresh failure, throws a
  /// friendly [SessionRecoveryException] instead of the raw backend error.
  Future<T> run<T>(
    Future<T> Function(String accessToken) action, {
    required bool Function(Object error) isSessionExpired,
  }) async {
    final token = await secureStorage.accessToken;
    if (token == null || token.isEmpty) {
      throw const SessionRecoveryException('You need to sign in again.');
    }

    try {
      return await action(token);
    } catch (e) {
      if (!isSessionExpired(e)) rethrow;

      final refreshed = await refresh();
      if (refreshed == null) {
        throw const SessionRecoveryException('Your session has expired. Please sign in again.');
      }
      return action(refreshed);
    }
  }
}
