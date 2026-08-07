import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'central_auth_api.dart';
import 'secure_storage_service.dart';
import 'session_recovery.dart';

/// Attaches the Central Auth access token to outgoing requests and, on a
/// refreshable 401, delegates to the shared [SessionRecovery] single-flight
/// refresh (also used by any code that calls Central Auth directly),
/// retrying the original request afterwards.
class AuthInterceptor extends Interceptor {
  final SecureStorageService secureStorage;
  final CentralAuthApi centralAuthApi;
  final void Function() onSessionExpired;
  final Dio? retryDio;
  final SessionRecovery sessionRecovery;

  // Note: [onSessionExpired] is accepted for API compatibility but is NOT
  // wired into the shared [SessionRecovery] singleton here — doing so per
  // instance would let whichever AuthInterceptor is constructed last (e.g.
  // a throwaway one inside ProfileService/SafetyService) silently
  // overwrite the app's real logout callback. Configure
  // `SessionRecovery.instance.onSessionExpired` exactly once, at app
  // startup (see `apiClientProvider`), instead.
  AuthInterceptor({
    required this.secureStorage,
    required this.centralAuthApi,
    required this.onSessionExpired,
    this.retryDio,
    SessionRecovery? sessionRecovery,
  }) : sessionRecovery = sessionRecovery ?? SessionRecovery.instance;

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

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
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
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    final failedAccessToken = _bearerToken(err.requestOptions.headers['Authorization']);
    final currentAccessToken = await secureStorage.accessToken;
    if (currentAccessToken != null &&
        currentAccessToken.isNotEmpty &&
        currentAccessToken != failedAccessToken) {
      final retried = await _retryWithAccessToken(err.requestOptions, currentAccessToken);
      if (retried != null) {
        handler.resolve(retried);
        return;
      }
    }

    // SessionRecovery.refresh() already clears the session and fires
    // onSessionExpired on a definitive failure (rotated refresh token
    // missing, refresh token expired/revoked, or save failure) — exactly
    // once, however many concurrent requests triggered it.
    final newAccessToken = await sessionRecovery.refresh();
    if (newAccessToken == null) {
      handler.next(err);
      return;
    }

    // Refresh succeeded; retry the original request once with a rebuilt
    // Authorization header. A failure here is not a session-expiry event.
    final retryOptions = err.requestOptions;
    final previousAuthorization = retryOptions.headers['Authorization'];
    retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
    try {
      final retryFactory = retryOptions.extra['multipartRetryFactory'];
      if (retryFactory is Future<FormData> Function()) {
        retryOptions.data = await retryFactory();
      }
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

  Future<Response<dynamic>?> _retryWithAccessToken(
    RequestOptions failedOptions,
    String accessToken,
  ) async {
    final retryOptions = failedOptions;
    final previousAuthorization = retryOptions.headers['Authorization'];
    retryOptions.headers['Authorization'] = 'Bearer $accessToken';
    try {
      final retryFactory = retryOptions.extra['multipartRetryFactory'];
      if (retryFactory is Future<FormData> Function()) {
        retryOptions.data = await retryFactory();
      }
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
      return await freshDio.fetch(retryOptions);
    } catch (retryError) {
      return null;
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
    if (data is Map) {
      final nestedError = data['error'];
      if (nestedError is Map && nestedError['code'] != null) {
        return nestedError['code'].toString().trim().toUpperCase();
      }
      if (data['code'] != null) {
        return data['code'].toString().trim().toUpperCase();
      }
    }
    return null;
  }

  String? _bearerToken(Object? authorization) {
    if (authorization is! String) return null;
    final value = authorization.trim();
    if (!value.toLowerCase().startsWith('bearer ')) return value.isEmpty ? null : value;
    final token = value.substring(7).trim();
    return token.isEmpty ? null : token;
  }
}
