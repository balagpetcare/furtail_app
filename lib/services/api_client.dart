import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/auth_interceptor.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/crash_reporting/crash_reporting_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dio-backed API client. Public method names/signatures/return
/// shapes/thrown-exception shape are preserved exactly from the previous
/// package:http implementation so every existing call site (posts/pets/
/// adoption/comments/feed/notifications/media/...) needs zero changes:
///  - success responses return the JSON-decoded body (`dynamic`)
///  - API failures surface as typed exceptions with readable status/code
class ApiClientException implements Exception {
  ApiClientException({
    required this.message,
    this.statusCode,
    this.code,
    this.dioExceptionType,
    this.method,
    this.url,
    this.responseData,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final String? dioExceptionType;
  final String? method;
  final String? url;
  final Object? responseData;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNetworkError =>
      dioExceptionType == 'connectionError' ||
      dioExceptionType == 'connectionTimeout' ||
      dioExceptionType == 'receiveTimeout' ||
      dioExceptionType == 'sendTimeout';

  @override
  String toString() => message;
}

class ApiClient {
  final Dio _dio;

  /// [dio] is a test-only seam — production call sites never pass it, so
  /// they always get the real `Dio` built here. Lets tests attach a
  /// request-short-circuiting interceptor to simulate server responses
  /// without a live network call.
  ///
  /// When [dio] is omitted and no [authInterceptor] is supplied, a default
  /// [AuthInterceptor] is attached automatically, built from the canonical
  /// [SecureStorageService]/[CentralAuthApi] singletons. This is a safety
  /// net for the many call sites that construct `ApiClient()` directly
  /// outside of Riverpod (`apiClientProvider` still passes its own
  /// [authInterceptor], wired to `onSessionExpired`, which takes precedence)
  /// — without it, those call sites would silently never attach a Bearer
  /// token to protected requests.
  ApiClient({AuthInterceptor? authInterceptor, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              // Callers pass full absolute URLs (as before), so no baseUrl here.
            ),
          ) {
    if (authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    } else if (dio == null) {
      _dio.interceptors.add(
        AuthInterceptor(
          secureStorage: SecureStorageService(),
          centralAuthApi: CentralAuthApi(),
          // No WidgetRef available here to drive AuthState; the interceptor
          // already clears the persisted session on a definitive failure,
          // which is what actually gates future requests.
          onSessionExpired: () {},
        ),
      );
    }
  }

  /// Test-only seam: whether this instance carries an [AuthInterceptor],
  /// regardless of whether it came from the default wiring above or from an
  /// explicit [authInterceptor] argument.
  @visibleForTesting
  bool get hasAuthInterceptorForTest =>
      _dio.interceptors.whereType<AuthInterceptor>().isNotEmpty;

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = <String, String>{"Content-Type": "application/json"};
    // Phase 5: X-Country-Code for API policy/context
    final prefs = await SharedPreferences.getInstance();
    final country = (prefs.getString("furtail_country_code") ?? 'BD').trim();
    headers["X-Country-Code"] = country.isEmpty ? 'BD' : country.toUpperCase();
    final state = prefs.getString("furtail_state_code");
    if (state != null && state.trim().isNotEmpty) {
      headers["X-State-Code"] = state.trim().toUpperCase();
    }
    return headers;
  }

  dynamic _safeDecode(dynamic data) {
    if (data == null) return {};
    if (data is String) {
      if (data.trim().isEmpty) return {};
      try {
        return data; // already handled by Dio's ResponseType.json in most cases
      } catch (_) {
        return {"raw": data};
      }
    }
    return data;
  }

  dynamic _handle(Response res, {required String method, required String url}) {
    final decoded = _safeDecode(res.data);

    if ((res.statusCode ?? 0) >= 200 && (res.statusCode ?? 0) < 300) {
      return decoded;
    }
    throw ApiClientException(
      message: _messageFromDecoded(decoded, fallback: 'API Error'),
      statusCode: res.statusCode,
      code: _codeFromDecoded(decoded),
      method: method,
      url: url,
      responseData: decoded,
    );
  }

  String _messageFromDecoded(dynamic decoded, {required String fallback}) {
    if (decoded is Map && decoded['message'] != null) {
      return decoded['message'].toString();
    }
    return fallback;
  }

  String? _codeFromDecoded(dynamic decoded) {
    if (decoded is Map && decoded['code'] != null) {
      return decoded['code'].toString();
    }
    return null;
  }

  ApiClientException _toApiClientException(
    DioException error, {
    required String method,
    required String url,
  }) {
    final decoded = _safeDecode(error.response?.data);
    return ApiClientException(
      message: _messageFromDecoded(
        decoded,
        fallback: error.message ?? 'API Error',
      ),
      statusCode: error.response?.statusCode,
      code: _codeFromDecoded(decoded),
      dioExceptionType: error.type.name,
      method: method,
      url: url,
      responseData: decoded,
    );
  }

  Future<T> _runHttp<T>(
    String method,
    String url,
    Future<T> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) {
        final error = _toApiClientException(e, method: method, url: url);
        await CrashReportingService.instance.recordNetworkError(
          method: method,
          url: url,
          error: error,
          statusCode: error.statusCode,
        );
        throw error;
      }
      rethrow;
    } catch (e, st) {
      final msg = e.toString();
      if (!msg.contains('API Error') && !msg.contains('Upload Error')) {
        await CrashReportingService.instance.recordNetworkError(
          method: method,
          url: url,
          error: e,
          stackTrace: st,
        );
      }
      rethrow;
    }
  }

  Future<dynamic> get(String url, {bool auth = true}) async {
    return _runHttp('GET', url, () async {
      final res = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: await _headers(auth: auth),
          extra: {'auth': auth},
        ),
      );
      return _handle(res, method: 'GET', url: url);
    });
  }

  Future<dynamic> post(
    String url,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _runHttp('POST', url, () async {
      final res = await _dio.post<dynamic>(
        url,
        data: body,
        options: Options(
          headers: await _headers(auth: auth),
          extra: {'auth': auth},
        ),
      );
      return _handle(res, method: 'POST', url: url);
    });
  }

  Future<dynamic> patch(
    String url,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _runHttp('PATCH', url, () async {
      final res = await _dio.patch<dynamic>(
        url,
        data: body,
        options: Options(
          headers: await _headers(auth: auth),
          extra: {'auth': auth},
        ),
      );
      return _handle(res, method: 'PATCH', url: url);
    });
  }

  Future<dynamic> delete(String url, {bool auth = true}) async {
    return _runHttp('DELETE', url, () async {
      final res = await _dio.delete<dynamic>(
        url,
        options: Options(
          headers: await _headers(auth: auth),
          extra: {'auth': auth},
        ),
      );
      return _handle(res, method: 'DELETE', url: url);
    });
  }

  Future<dynamic> multipartPost({
    required String url,
    required String fieldName,
    required String filePath,
    bool auth = true,
    Map<String, String>? fields,
  }) async {
    return _runHttp('POST', url, () async {
      final formData = FormData.fromMap({
        if (fields != null) ...fields,
        fieldName: await MultipartFile.fromFile(filePath),
      });

      // multipart requests still need country/state headers, and (when
      // `auth: true`) the Authorization header — the latter is normally
      // attached by AuthInterceptor's onRequest hook, which runs for every
      // Dio request including this one, so we don't attach it manually here.
      final headers = await _headers(auth: auth);
      headers.remove('Content-Type'); // let Dio set the multipart boundary

      final res = await _dio.post<dynamic>(
        url,
        data: formData,
        options: Options(headers: headers, extra: {'auth': auth}),
      );
      return _safeDecode(res.data);
    });
  }
}

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final interceptor = AuthInterceptor(
    secureStorage: ref.read(secureStorageServiceProvider),
    centralAuthApi: ref.read(centralAuthApiProvider),
    onSessionExpired: () {
      ref.read(authControllerProvider.notifier).forceLogout();
    },
  );
  final client = ApiClient(authInterceptor: interceptor);
  if (kDebugMode) {
    developer.log(
      'apiClientProvider built instance=${client.hashCode}',
      name: 'ApiClient',
    );
  }
  return client;
});
