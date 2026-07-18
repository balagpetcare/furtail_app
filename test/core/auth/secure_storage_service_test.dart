// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';

class _FailingWriteSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {
    'central_access_token': 'old-access-token',
    'central_refresh_token': 'old-refresh-token',
  };

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
    if (key == 'central_refresh_token') {
      throw StateError('simulated storage failure');
    }
    _store[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saveTokens rolls back to the previous pair if rotating refresh storage fails',
    () async {
      FlutterSecureStoragePlatform.instance =
          _FailingWriteSecureStoragePlatform();
      final storage = SecureStorageService();

      await expectLater(
        storage.saveTokens(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
        ),
        throwsStateError,
      );

      expect(await storage.accessToken, equals('old-access-token'));
      expect(await storage.refreshToken, equals('old-refresh-token'));
    },
  );
}
