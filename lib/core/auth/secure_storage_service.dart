import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const bool _e2eTestMode = bool.fromEnvironment('E2E_TEST_MODE');

/// Wraps [FlutterSecureStorage] for the Central Auth OAuth2 token pair.
///
/// Only the access/refresh tokens live here — no user profile data. Profile
/// data is fetched from `/me` after bootstrap and cached (if at all) via
/// [LocalStorage] display-cache helpers, not here.
class SecureStorageService {
  final FlutterSecureStorage _storage;
  static _TestSecureStorageState? _testState;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'central_access_token';
  static const _refreshTokenKey = 'central_refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (_e2eTestMode && _testState != null) {
      _testState!
        ..accessToken = accessToken
        ..refreshToken = refreshToken;
      return;
    }
    final previousAccessToken = await _storage.read(key: _accessTokenKey);
    final previousRefreshToken = await _storage.read(key: _refreshTokenKey);

    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (_) {
      // Best-effort rollback so callers never observe a mixed token pair.
      try {
        if (previousAccessToken == null) {
          await _storage.delete(key: _accessTokenKey);
        } else {
          await _storage.write(
            key: _accessTokenKey,
            value: previousAccessToken,
          );
        }
        if (previousRefreshToken == null) {
          await _storage.delete(key: _refreshTokenKey);
        } else {
          await _storage.write(
            key: _refreshTokenKey,
            value: previousRefreshToken,
          );
        }
      } catch (_) {
        // If rollback fails too, the caller must treat the session as lost.
      }
      rethrow;
    }
  }

  Future<String?> get accessToken async {
    if (_e2eTestMode && _testState != null) {
      return _testState!.accessToken;
    }
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> get refreshToken async {
    if (_e2eTestMode && _testState != null) {
      return _testState!.refreshToken;
    }
    return _storage.read(key: _refreshTokenKey);
  }

  Future<bool> get hasSession async => (await accessToken) != null;

  Future<void> clear() async {
    if (_e2eTestMode && _testState != null) {
      _testState!
        ..accessToken = null
        ..refreshToken = null;
      return;
    }
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  @visibleForTesting
  static void installTestState({String? accessToken, String? refreshToken}) {
    if (!_e2eTestMode) {
      throw StateError('E2E test storage can only be installed in test mode.');
    }
    _testState = _TestSecureStorageState(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @visibleForTesting
  static void clearTestState() {
    _testState = null;
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class _TestSecureStorageState {
  _TestSecureStorageState({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
}
