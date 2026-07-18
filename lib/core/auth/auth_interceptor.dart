import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'central_auth_api.dart';
import 'secure_storage_service.dart';

/// Attaches the Central Auth access token to outgoing requests and, on a
/// refreshable 401, refreshes the token exactly once for any number of
/// concurrently failing requests (mutex via a shared [Completer]),
/// retrying the original request afterwards.
class AuthInterceptor extends Interceptor {
  final SecureStorageService secureStorage;
  final CentralAuthApi centralAuthApi;
  final void Function() onSessionExpired;
  final Dio? retryDio;

  AuthInterceptor({
    required this.secureStorage,
    required this.centralAuthApi,
    required this.onSessionExpired,
    this.retryDio,
  });

  static const _authBypassPaths = {
    '/auth/login',
    '/auth/login/phone',
    '/auth/register',
    '/auth/forgot-password',
    '/auth/reset-password',
    '/auth/logout',
    '/auth/refresh',
    '/auth/bootstrap',
    '/auth/otp/request',
    '/auth/otp/verify',
  };

  bool _isIdentityLoginPath(String path) {
    // '/auth/identity/:provider' (login/exchange) is public; only the
    // '/link' variant requires an existing session and should NOT bypass.
    return path.startsWith('/auth/identity/') && !path.endsWith('/link');
  }

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Callers opt out via `options.extra['auth'] = false` (ApiClient passes
    // this through from its own `auth` parameter) to preserve the previous
    // package:http implementation's behavior of never attaching a token to
    // explicitly-public requests, even if a session happens to exist.
    final authRequested = options.extra['auth'] != false;
    String? token;
    if (authRequested) {
      token = await secureStorage.accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    if (kDebugMode) {
      developer.log(
        'authRequested=$authRequested tokenAvailable=${token != null} '
        'attached=${token != null} path=${options.path}',
        name: 'AuthInterceptor',
      );
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    final refreshOutcome = await _refreshAccessToken();
    if (refreshOutcome.accessToken == null) {
      if (refreshOutcome.shouldLogout) {
        await secureStorage.clear();
        onSessionExpired();
      }
      handler.next(err);
      return;
    }

    // Refresh succeeded; retry the original request once with a rebuilt
    // Authorization header. A failure here is not a session-expiry event.
    final retryOptions = err.requestOptions;
    final previousAuthorization = retryOptions.headers['Authorization'];
    retryOptions.headers['Authorization'] =
        'Bearer ${refreshOutcome.accessToken}';
    try {
      final freshDio =
          retryDio ??
          Dio(
            BaseOptions(
              baseUrl: retryOptions.baseUrl,
              connectTimeout: retryOptions.connectTimeout,
              receiveTimeout: retryOptions.receiveTimeout,
              headers: retryOptions.headers,
            ),
          );
      final response = await freshDio.fetch(retryOptions);
      handler.resolve(response);
    } catch (retryError) {
      handler.next(retryError is DioException ? retryError : err);
    } finally {
      if (previousAuthorization == null) {
        retryOptions.headers.remove('Authorization');
      } else {
        retryOptions.headers['Authorization'] = previousAuthorization;
      }
    }
  }

  bool _shouldAttemptRefresh(DioException err) {
    if (err.response?.statusCode != 401) return false;
    final path = err.requestOptions.uri.path;
    if (_authBypassPaths.contains(path) || _isIdentityLoginPath(path)) {
      return false;
    }
    return _responseCode(err) == 'CENTRAL_TOKEN_EXPIRED';
  }

  String? _responseCode(DioException err) {
    final data = err.response?.data;
    if (data is Map && data['code'] != null) {
      return data['code'].toString().trim().toUpperCase();
    }
    return null;
  }

  Future<_RefreshOutcome> _refreshAccessToken() async {
    if (_isRefreshing) {
      final awaited = await _refreshCompleter?.future;
      return _RefreshOutcome(accessToken: awaited, shouldLogout: false);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();
    try {
      final refreshToken = await secureStorage.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter?.complete(null);
        return const _RefreshOutcome(accessToken: null, shouldLogout: true);
      }

      final result = await centralAuthApi.refreshToken(refreshToken);
      final rotatedRefreshToken = result.refreshToken;
      if (rotatedRefreshToken == null || rotatedRefreshToken.isEmpty) {
        _refreshCompleter?.complete(null);
        return const _RefreshOutcome(accessToken: null, shouldLogout: true);
      }

      try {
        await secureStorage.saveTokens(
          accessToken: result.accessToken,
          refreshToken: rotatedRefreshToken,
        );
      } catch (_) {
        _refreshCompleter?.complete(null);
        return const _RefreshOutcome(accessToken: null, shouldLogout: true);
      }

      _refreshCompleter?.complete(result.accessToken);
      return _RefreshOutcome(
        accessToken: result.accessToken,
        shouldLogout: false,
      );
    } on CentralAuthException catch (e) {
      final shouldLogout = e.isDefinitiveSessionFailure || e.isUnauthorized;
      _refreshCompleter?.complete(null);
      return _RefreshOutcome(accessToken: null, shouldLogout: shouldLogout);
    } catch (_) {
      _refreshCompleter?.complete(null);
      return const _RefreshOutcome(accessToken: null, shouldLogout: false);
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}

class _RefreshOutcome {
  const _RefreshOutcome({
    required this.accessToken,
    required this.shouldLogout,
  });

  final String? accessToken;
  final bool shouldLogout;
}
