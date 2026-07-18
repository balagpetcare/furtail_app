// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/auth_interceptor.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory fake backing FlutterSecureStorage's platform channel, so
/// SecureStorageService can be exercised without a real platform plugin.
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _store.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _store[key];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return Map.of(_store);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }
}

class _CountingCentralAuthApi implements CentralAuthApi {
  @override
  Future<CentralAuthTokenResult> exchangeMobileCode({
    required String code,
    required String codeVerifier,
  }) async {
    throw UnimplementedError('exchangeMobileCode not stubbed');
  }

  int refreshCallCount = 0;
  final CentralAuthTokenResult successResult;
  final CentralAuthException? refreshError;

  _CountingCentralAuthApi({
    CentralAuthTokenResult? successResult,
    this.refreshError,
  }) : successResult =
           successResult ??
           CentralAuthTokenResult(
             accessToken: 'new-access-token',
             refreshToken: 'new-refresh-token',
             expiresIn: 3600,
           );

  @override
  Future<CentralAuthTokenResult> refreshToken(String refreshToken) async {
    refreshCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (refreshError != null) {
      throw refreshError!;
    }
    return successResult;
  }

  @override
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})> login({
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CentralAuthUser> register({
    required String displayName,
    String? phone,
    String? email,
    String? username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> forgotPassword({
    required String email,
    String? clientId,
  }) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> logout(String accessToken, {String? refreshToken}) async {}

  @override
  Future<void> revoke(String accessToken) async {}

  @override
  Future<CentralAuthBootstrap> bootstrap({String? clientId}) =>
      throw UnimplementedError();

  @override
  Future<void> requestOtp({
    required String channel,
    required String recipient,
  }) => throw UnimplementedError();

  @override
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})> verifyOtp({
    required String channel,
    required String recipient,
    required String code,
  }) => throw UnimplementedError();

  @override
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})> loginPhone({
    required String phone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})>
  identityLogin({
    required String provider,
    String? idToken,
    String? accessToken,
    String? nonce,
    String? orgSlug,
  }) => throw UnimplementedError();

  @override
  Future<void> identityLink({
    required String accessToken,
    required String provider,
    String? idToken,
    String? providerAccessToken,
    String? nonce,
    String? orgSlug,
  }) => throw UnimplementedError();

  @override
  Future<void> setPassword({
    required String accessToken,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<CentralAuthUser> me(String accessToken) => throw UnimplementedError();

  @override
  Future<void> logoutAllOtherDevices(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<List<CentralAuthSession>> listSessions(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<void> revokeSession(String accessToken, String sessionId) =>
      throw UnimplementedError();
}

Future<void> _driveError(
  AuthInterceptor interceptor, {
  required int statusCode,
  required String path,
  required String code,
}) async {
  final requestOptions = RequestOptions(
    path: path,
    baseUrl: 'http://127.0.0.1:1',
  );
  final err = DioException(
    requestOptions: requestOptions,
    response: Response(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: {'success': false, 'code': code, 'message': code},
    ),
    type: DioExceptionType.badResponse,
  );
  final handler = ErrorInterceptorHandler();
  // ignore: invalid_use_of_protected_member, unawaited_futures
  handler.future.then<void>((_) {}, onError: (_) {});
  try {
    await interceptor.onError(err, handler);
  } catch (_) {
    // `handler.next(err)` completes the interceptor future with a thrown
    // DioException in this isolated harness. The caller only cares about the
    // side effects, not the propagated completion detail.
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

Dio _buildRetryDio(List<String?> capturedAuthHeaders) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        capturedAuthHeaders.add(options.headers['Authorization']?.toString());
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true},
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();

  group('AuthInterceptor refresh lock', () {
    late SecureStorageService secureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secureStorage = SecureStorageService();
      await secureStorage.clear();
      await secureStorage.saveTokens(
        accessToken: 'expired-token',
        refreshToken: 'refresh-token',
      );
    });

    test(
      'one expired request refreshes once, persists the rotated pair, and retries with it',
      () async {
        final capturedAuthHeaders = <String?>[];
        final centralAuthApi = _CountingCentralAuthApi();
        var sessionExpiredCalls = 0;
        final interceptor = AuthInterceptor(
          secureStorage: secureStorage,
          centralAuthApi: centralAuthApi,
          onSessionExpired: () => sessionExpiredCalls++,
          retryDio: _buildRetryDio(capturedAuthHeaders),
        );

        await _driveError(
          interceptor,
          statusCode: 401,
          path: '/protected',
          code: 'CENTRAL_TOKEN_EXPIRED',
        );

        expect(centralAuthApi.refreshCallCount, equals(1));
        expect(sessionExpiredCalls, equals(0));
        expect(await secureStorage.accessToken, equals('new-access-token'));
        expect(await secureStorage.refreshToken, equals('new-refresh-token'));
        expect(capturedAuthHeaders, equals(['Bearer new-access-token']));
      },
    );

    test(
      'several concurrent expired requests share one refresh call',
      () async {
        final capturedAuthHeaders = <String?>[];
        final centralAuthApi = _CountingCentralAuthApi();
        var sessionExpiredCalls = 0;
        final interceptor = AuthInterceptor(
          secureStorage: secureStorage,
          centralAuthApi: centralAuthApi,
          onSessionExpired: () => sessionExpiredCalls++,
          retryDio: _buildRetryDio(capturedAuthHeaders),
        );

        await Future.wait([
          _driveError(
            interceptor,
            statusCode: 401,
            path: '/protected-a',
            code: 'CENTRAL_TOKEN_EXPIRED',
          ),
          _driveError(
            interceptor,
            statusCode: 401,
            path: '/protected-b',
            code: 'CENTRAL_TOKEN_EXPIRED',
          ),
          _driveError(
            interceptor,
            statusCode: 401,
            path: '/protected-c',
            code: 'CENTRAL_TOKEN_EXPIRED',
          ),
        ]);

        expect(centralAuthApi.refreshCallCount, equals(1));
        expect(sessionExpiredCalls, equals(0));
        expect(await secureStorage.accessToken, equals('new-access-token'));
        expect(await secureStorage.refreshToken, equals('new-refresh-token'));
        expect(capturedAuthHeaders, everyElement('Bearer new-access-token'));
      },
    );

    test('failed refresh clears the session exactly once', () async {
      final failingApi = _CountingCentralAuthApi(
        refreshError: CentralAuthException(
          message: 'Refresh token was revoked',
          statusCode: 401,
          code: 'TOKEN_REVOKED',
        ),
      );
      var sessionExpiredCalls = 0;
      final interceptor = AuthInterceptor(
        secureStorage: secureStorage,
        centralAuthApi: failingApi,
        onSessionExpired: () => sessionExpiredCalls++,
      );

      await _driveError(
        interceptor,
        statusCode: 401,
        path: '/protected',
        code: 'CENTRAL_TOKEN_EXPIRED',
      );

      expect(failingApi.refreshCallCount, equals(1));
      expect(sessionExpiredCalls, equals(1));
      expect(await secureStorage.accessToken, isNull);
      expect(await secureStorage.refreshToken, isNull);
    });

    test('403 does not trigger refresh or logout', () async {
      final centralAuthApi = _CountingCentralAuthApi();
      var sessionExpiredCalls = 0;
      final interceptor = AuthInterceptor(
        secureStorage: secureStorage,
        centralAuthApi: centralAuthApi,
        onSessionExpired: () => sessionExpiredCalls++,
      );

      await _driveError(
        interceptor,
        statusCode: 403,
        path: '/protected',
        code: 'FORBIDDEN',
      );

      expect(centralAuthApi.refreshCallCount, equals(0));
      expect(sessionExpiredCalls, equals(0));
      expect(await secureStorage.accessToken, equals('expired-token'));
      expect(await secureStorage.refreshToken, equals('refresh-token'));
    });

    test(
      'refresh endpoint is bypassed and never recursively intercepted',
      () async {
        final centralAuthApi = _CountingCentralAuthApi();
        var sessionExpiredCalls = 0;
        final interceptor = AuthInterceptor(
          secureStorage: secureStorage,
          centralAuthApi: centralAuthApi,
          onSessionExpired: () => sessionExpiredCalls++,
        );

        await _driveError(
          interceptor,
          statusCode: 401,
          path: '/auth/refresh',
          code: 'CENTRAL_TOKEN_EXPIRED',
        );

        expect(centralAuthApi.refreshCallCount, equals(0));
        expect(sessionExpiredCalls, equals(0));
        expect(await secureStorage.accessToken, equals('expired-token'));
        expect(await secureStorage.refreshToken, equals('refresh-token'));
      },
    );

    test(
      'temporary network failure during refresh preserves the stored session',
      () async {
        final centralAuthApi = _CountingCentralAuthApi(
          refreshError: CentralAuthException(
            message: 'offline',
            dioExceptionType: 'connectionError',
          ),
        );
        var sessionExpiredCalls = 0;
        final interceptor = AuthInterceptor(
          secureStorage: secureStorage,
          centralAuthApi: centralAuthApi,
          onSessionExpired: () => sessionExpiredCalls++,
        );

        await _driveError(
          interceptor,
          statusCode: 401,
          path: '/protected',
          code: 'CENTRAL_TOKEN_EXPIRED',
        );

        expect(centralAuthApi.refreshCallCount, equals(1));
        expect(sessionExpiredCalls, equals(0));
        expect(await secureStorage.accessToken, equals('expired-token'));
        expect(await secureStorage.refreshToken, equals('refresh-token'));
      },
    );

    test(
      'ApiClient surfaces typed non-2xx responses instead of generic exceptions',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        final apiClient = ApiClient(dio: dio);
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'success': false,
                    'code': 'IDENTITY_CONFLICT',
                    'message':
                        'Multiple local accounts match this email; manual resolution required',
                  },
                ),
              );
            },
          ),
        );

        await expectLater(
          apiClient.get('http://127.0.0.1:1/profile', auth: false),
          throwsA(
            isA<ApiClientException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.code, 'code', 'IDENTITY_CONFLICT')
                .having(
                  (e) => e.message,
                  'message',
                  'Multiple local accounts match this email; manual resolution required',
                ),
          ),
        );
      },
    );
  });
}
