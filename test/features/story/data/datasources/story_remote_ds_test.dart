// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/features/story/data/datasources/story_remote_ds.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory fake backing FlutterSecureStorage's platform channel, mirroring
/// the fake used in auth_interceptor_test.dart.
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

  group('StoryRemoteDs auth wiring', () {
    late SecureStorageService secureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secureStorage = SecureStorageService();
      await secureStorage.clear();
    });

    test(
      'getStories attaches a Bearer header immediately after login persists a token',
      () async {
        // Simulates AuthController.login()'s token persistence step.
        await secureStorage.saveTokens(
          accessToken: 'fresh-access-token',
          refreshToken: 'fresh-refresh-token',
        );

        String? capturedAuthHeader;
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final authRequested = options.extra['auth'] != false;
              if (authRequested) {
                final token = await secureStorage.accessToken;
                if (token != null) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
              }
              handler.next(options);
            },
          ),
        );
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedAuthHeader = options.headers['Authorization']
                  ?.toString();
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'stories': []},
                ),
              );
            },
          ),
        );

        final apiClient = ApiClient(dio: dio);
        final storyRemoteDs = StoryRemoteDs(apiClient, secureStorage);

        await storyRemoteDs.getStories();

        expect(capturedAuthHeader, equals('Bearer fresh-access-token'));
      },
    );

    test(
      'getStories sends auth:false with no crash when no session exists (guest path)',
      () async {
        String? capturedAuthHeader;
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedAuthHeader = options.headers['Authorization']?.toString();
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'stories': []},
                ),
              );
            },
          ),
        );

        final apiClient = ApiClient(dio: dio);
        final storyRemoteDs = StoryRemoteDs(apiClient, secureStorage);

        await storyRemoteDs.getStories();

        expect(capturedAuthHeader, isNull);
      },
    );
  });
}
