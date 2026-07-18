// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
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
  Future<void> deleteAll({required Map<String, String> options}) async {
    _store.clear();
  }

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();

  group('ApiClient() default construction', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final secureStorage = SecureStorageService();
      await secureStorage.clear();
    });

    test('a bare ApiClient() never disables auth just because no legacy '
        'SharedPreferences token key is set — it self-attaches AuthInterceptor '
        'so a real Central Auth session still gets a Bearer header', () async {
      await SecureStorageService().saveTokens(
        accessToken: 'session-access-token',
        refreshToken: 'session-refresh-token',
      );

      // No SharedPreferences 'token' key is ever written — only the
      // canonical SecureStorageService session exists.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), isNull);

      // ApiClient() built with zero DI wiring (the pattern used by
      // SocialService, ProfileService, settingsRepositoryProvider, and the
      // adoption screens) must still resolve the real session via its
      // default AuthInterceptor.
      final client = ApiClient();
      expect(client.hasAuthInterceptorForTest, isTrue);
    });

    test('a test-seam ApiClient(dio: ...) does not get a duplicate default '
        'interceptor injected behind the caller\'s back', () {
      final dio = Dio();
      final client = ApiClient(dio: dio);
      expect(client.hasAuthInterceptorForTest, isFalse);
    });
  });
}
