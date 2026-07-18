// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/auth_identifier_normalizer.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/network/api_config.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory fake backing FlutterSecureStorage's platform channel.
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _store.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _store.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _store[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_store);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }
}

/// Fake CentralAuthApi returning a fixed successful login.
class _FakeCentralAuthApi implements CentralAuthApi {
  @override
  Future<CentralAuthTokenResult> exchangeMobileCode({
    required String code,
    required String codeVerifier,
  }) async {
    throw UnimplementedError('exchangeMobileCode not stubbed');
  }

  @override
  Future<({CentralAuthTokenResult tokens, CentralAuthUser user})> login({
    required String identifier,
    required String password,
  }) async {
    return (
      tokens: CentralAuthTokenResult(
        accessToken: 'central-access',
        refreshToken: 'central-refresh',
      ),
      user: CentralAuthUser(id: 'central-user-id', email: identifier),
    );
  }

  @override
  Future<CentralAuthUser> register({
    required String displayName,
    String? phone,
    String? email,
    String? username,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<CentralAuthTokenResult> refreshToken(String refreshToken) =>
      throw UnimplementedError();

  @override
  Future<void> logout(String accessToken, {String? refreshToken}) async {}

  @override
  Future<void> revoke(String accessToken) async {}

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

/// Builds an [ApiClient] whose Dio never touches the network: a lead
/// interceptor short-circuits every request with [handlerResponse] before
/// Dio would attempt to resolve a host.
ApiClient _stubbedApiClient(
  Future<void> Function(
    RequestOptions options,
    RequestInterceptorHandler handler,
  )
  onRequest,
) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return ApiClient(dio: dio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();

  late SecureStorageService secureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secureStorage = SecureStorageService();
    await secureStorage.clear();
  });

  group('AuthController.login', () {
    test(
      'requests the profile at an absolute URL built from ApiConfig, not a bare path',
      () async {
        String? capturedUrl;
        final apiClient = _stubbedApiClient((options, handler) async {
          capturedUrl = options.uri.toString();
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'user': {
                  'id': 1,
                  'displayName': 'Test User',
                  'email': 'test@example.com',
                },
              },
            ),
          );
        });

        final controller = AuthController(
          secureStorage,
          _FakeCentralAuthApi(),
          apiClient,
        );
        await controller.login(
          identifier: 'test@example.com',
          password: 'password123',
          identifierType: AuthIdentifierType.email,
        );

        expect(capturedUrl, isNotNull);
        final uri = Uri.parse(capturedUrl!);
        expect(
          uri.hasAuthority,
          isTrue,
          reason: 'URL must be absolute, not "/api/v1/auth/me"',
        );
        expect(uri.host, equals(Uri.parse(ApiConfig.host).host));
        expect(uri.path, endsWith('/auth/me'));
      },
    );

    test(
      'successful Central Auth login followed by successful Furtail profile fetch authenticates and stores tokens',
      () async {
        final apiClient = _stubbedApiClient((options, handler) async {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'user': {
                  'id': 42,
                  'displayName': 'Jane Doe',
                  'email': 'jane@example.com',
                },
              },
            ),
          );
        });

        final controller = AuthController(
          secureStorage,
          _FakeCentralAuthApi(),
          apiClient,
        );
        await controller.login(
          identifier: 'jane@example.com',
          password: 'password123',
          identifierType: AuthIdentifierType.email,
        );

        expect(controller.state.status, AuthStatus.authenticated);
        expect(controller.state.profile?.name, 'Jane Doe');
        expect(await secureStorage.accessToken, 'central-access');
        expect(await secureStorage.refreshToken, 'central-refresh');
      },
    );

    test(
      'successful Central Auth login followed by an unreachable Furtail API keeps the session authenticated while surfacing a recoverable profile error',
      () async {
        final apiClient = _stubbedApiClient((options, handler) async {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: 'Connection refused',
            ),
          );
        });

        final controller = AuthController(
          secureStorage,
          _FakeCentralAuthApi(),
          apiClient,
        );

        await controller.login(
          identifier: 'jane@example.com',
          password: 'password123',
          identifierType: AuthIdentifierType.email,
        );

        expect(controller.state.status, AuthStatus.authenticated);
        expect(controller.state.profile, isNull);
        expect(controller.state.lastError, contains('reach'));
        expect(await secureStorage.accessToken, 'central-access');
      },
    );
  });
}
