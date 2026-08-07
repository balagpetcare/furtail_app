import 'package:furtail_app/core/auth/auth_interceptor.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';

import '../../../services/api_client.dart';
import '../../../core/network/api_config.dart';

/// Blocked / muted / restricted user management.
/// Backend (Furtail Node API) routes used:
/// - GET/POST/DELETE /api/v1/social/block/:userId, /api/v1/social/blocked
/// - GET/POST/DELETE /api/v1/social/mute/:userId, /api/v1/social/muted
/// - GET/POST/DELETE /api/v1/social/restrict/:userId, /api/v1/social/restricted
class SafetyService {
  final ApiClient _client;

  SafetyService({ApiClient? client})
    : _client =
          client ??
          ApiClient(
            authInterceptor: AuthInterceptor(
              secureStorage: SecureStorageService(),
              centralAuthApi: CentralAuthApi(),
              onSessionExpired: () {},
            ),
          );

  List<int> _parseUserIds(dynamic response) {
    final body = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
    final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
    final items = (data['items'] as List?) ?? const [];
    return items
        .map((e) => e is Map ? e['userId'] : null)
        .whereType<Object>()
        .map((v) => int.tryParse(v.toString()))
        .whereType<int>()
        .toList();
  }

  /// Best-effort lookup of a user's public display name/username for a raw
  /// id from the block/mute/restrict lists. Returns null on any failure so
  /// callers can fall back to showing the id.
  Future<Map<String, String?>?> lookupUser(int userId) async {
    try {
      final response = await _client.get('${ApiConfig.apiV1}/user/$userId', auth: true);
      final body = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
      return {
        'displayName': data['displayName']?.toString() ?? data['name']?.toString(),
        'username': data['username']?.toString(),
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> listBlocked() async {
    return _parseUserIds(await _client.get('${ApiConfig.apiV1}/social/blocked', auth: true));
  }

  Future<void> block(int userId) async {
    await _client.post('${ApiConfig.apiV1}/social/block/$userId', const {}, auth: true);
  }

  Future<void> unblock(int userId) async {
    await _client.delete('${ApiConfig.apiV1}/social/block/$userId', auth: true);
  }

  Future<List<int>> listMuted() async {
    return _parseUserIds(await _client.get('${ApiConfig.apiV1}/social/muted', auth: true));
  }

  Future<void> mute(int userId) async {
    await _client.post('${ApiConfig.apiV1}/social/mute/$userId', const {}, auth: true);
  }

  Future<void> unmute(int userId) async {
    await _client.delete('${ApiConfig.apiV1}/social/mute/$userId', auth: true);
  }

  Future<List<int>> listRestricted() async {
    return _parseUserIds(await _client.get('${ApiConfig.apiV1}/social/restricted', auth: true));
  }

  Future<void> restrict(int userId) async {
    await _client.post('${ApiConfig.apiV1}/social/restrict/$userId', const {}, auth: true);
  }

  Future<void> unrestrict(int userId) async {
    await _client.delete('${ApiConfig.apiV1}/social/restrict/$userId', auth: true);
  }
}
