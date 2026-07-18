import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] for the Central Auth OAuth2 token pair.
///
/// Only the access/refresh tokens live here — no user profile data. Profile
/// data is fetched from `/me` after bootstrap and cached (if at all) via
/// [LocalStorage] display-cache helpers, not here.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'central_access_token';
  static const _refreshTokenKey = 'central_refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
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

  Future<String?> get accessToken async => _storage.read(key: _accessTokenKey);

  Future<String?> get refreshToken async =>
      _storage.read(key: _refreshTokenKey);

  Future<bool> get hasSession async => (await accessToken) != null;

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
