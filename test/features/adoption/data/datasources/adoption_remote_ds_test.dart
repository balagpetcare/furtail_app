// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/network/api_config.dart';
import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('AdoptionRemoteDs optional-auth wiring', () {
    late SecureStorageService secureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secureStorage = SecureStorageService();
      await secureStorage.clear();
    });

    test(
      'fetchAdoptions requests auth when a Central Auth session exists, '
      'even though the legacy SharedPreferences token key is absent',
      () async {
        await secureStorage.saveTokens(
          accessToken: 'real-access-token',
          refreshToken: 'real-refresh-token',
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('token'), isNull); // legacy key never written

        bool? capturedAuthFlag;
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedAuthFlag = options.extra['auth'] as bool?;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {'items': []},
                  },
                ),
              );
            },
          ),
        );
        final apiClient = ApiClient(dio: dio);
        final ds = AdoptionRemoteDs(apiClient, secureStorage);

        await ds.fetchAdoptions();

        expect(capturedAuthFlag, isTrue);
      },
    );

    test('fetchAdoptions remains anonymous (auth: false) for a genuine guest '
        'with no Central Auth session', () async {
      bool? capturedAuthFlag;
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedAuthFlag = options.extra['auth'] as bool?;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {'items': []},
                },
              ),
            );
          },
        ),
      );
      final apiClient = ApiClient(dio: dio);
      final ds = AdoptionRemoteDs(apiClient, secureStorage);

      await ds.fetchAdoptions();

      expect(capturedAuthFlag, isFalse);
    });

    test(
      'applyToAdopt posts to the canonical adoption applications endpoint',
      () async {
        String? capturedPath;
        String? capturedMethod;
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.uri.toString();
              capturedMethod = options.method;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {'id': 99, 'status': 'SUBMITTED'},
                  },
                ),
              );
            },
          ),
        );
        final apiClient = ApiClient(dio: dio);
        final ds = AdoptionRemoteDs(apiClient, secureStorage);
        await secureStorage.saveTokens(
          accessToken: 'real-access-token',
          refreshToken: 'real-refresh-token',
        );

        await ds.applyToAdopt(42, {
          'applicantName': 'Member One',
          'applicantPhone': '0123456789',
        });

        expect(capturedMethod, 'POST');
        expect(capturedPath, ApiEndpoints.adoptionApplications(42));
      },
    );

    test(
      'fetchMyAdoptionListings uses the canonical owner-list endpoint',
      () async {
        String? capturedPath;
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.uri.toString();
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {'items': []},
                  },
                ),
              );
            },
          ),
        );
        final apiClient = ApiClient(dio: dio);
        final ds = AdoptionRemoteDs(apiClient, secureStorage);
        await secureStorage.saveTokens(
          accessToken: 'real-access-token',
          refreshToken: 'real-refresh-token',
        );

        await ds.fetchMyAdoptionListings();

        expect(capturedPath, '${ApiConfig.apiV1}/adoptions/my?page=1&limit=20');
      },
    );

    test(
      'fetchAdoptions uses the public feed endpoint and unwraps data.items',
      () async {
        String? capturedPath;
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.uri.toString();
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'items': [
                        {'id': 1, 'name': 'Proof listing'},
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );
        final apiClient = ApiClient(dio: dio);
        final ds = AdoptionRemoteDs(apiClient, secureStorage);

        final items = await ds.fetchAdoptions(limit: 5, page: 2);

        expect(
          capturedPath,
          '${ApiConfig.apiV1}/adoptions/feed?page=2&limit=5',
        );
        expect(items, hasLength(1));
        expect(items.first['id'], 1);
      },
    );

    test(
      'createAdoptionListing posts to the draft creation endpoint',
      () async {
        String? capturedPath;
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.uri.toString();
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {'id': 7, 'status': 'DRAFT'},
                  },
                ),
              );
            },
          ),
        );
        final apiClient = ApiClient(dio: dio);
        final ds = AdoptionRemoteDs(apiClient, secureStorage);
        await secureStorage.saveTokens(
          accessToken: 'real-access-token',
          refreshToken: 'real-refresh-token',
        );

        await ds.createAdoptionListing({'submitNow': false});

        expect(capturedPath, '${ApiConfig.apiV1}/adoptions/drafts');
      },
    );

    test('updateAdoptionListing posts to the draft update endpoint', () async {
      String? capturedPath;
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPath = options.uri.toString();
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {'id': 7, 'status': 'DRAFT'},
                },
              ),
            );
          },
        ),
      );
      final apiClient = ApiClient(dio: dio);
      final ds = AdoptionRemoteDs(apiClient, secureStorage);
      await secureStorage.saveTokens(
        accessToken: 'real-access-token',
        refreshToken: 'real-refresh-token',
      );

      await ds.updateAdoptionListing(7, {'submitNow': false});

      expect(capturedPath, '${ApiConfig.apiV1}/adoptions/7/draft');
    });

    test('submitAdoptionForReview posts to the publish endpoint', () async {
      String? capturedPath;
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPath = options.uri.toString();
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {'id': 7, 'status': 'PUBLISHED'},
                },
              ),
            );
          },
        ),
      );
      final apiClient = ApiClient(dio: dio);
      final ds = AdoptionRemoteDs(apiClient, secureStorage);
      await secureStorage.saveTokens(
        accessToken: 'real-access-token',
        refreshToken: 'real-refresh-token',
      );

      await ds.submitAdoptionForReview(7);

      expect(capturedPath, '${ApiConfig.apiV1}/adoptions/7/publish');
    });
  });
}
