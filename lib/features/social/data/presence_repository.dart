import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import 'models/presence_info.dart';

/// Thin dio wrapper for the Active Status presence API
/// (`presence.routes.ts`) — no caching, timers, or business logic here;
/// that lives in `presence_providers.dart`. Mirrors the shape of
/// `MessagingService`/`SocialService`.
class PresenceRepository {
  PresenceRepository({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Map<String, dynamic> _asMap(dynamic decoded) =>
      (decoded as Map).cast<String, dynamic>();

  Map<String, dynamic> _data(dynamic decoded) {
    final map = _asMap(decoded);
    return (map['data'] as Map?)?.cast<String, dynamic>() ?? map;
  }

  /// Signals this session is active. Best-effort: callers should swallow
  /// failures rather than surfacing them, since a missed heartbeat is
  /// recovered by the next one.
  Future<void> heartbeat() async {
    await _client.post(ApiEndpoints.presenceHeartbeat(), const {});
  }

  /// Best-effort explicit "going offline" signal (backgrounded, logout).
  Future<void> goOffline() async {
    await _client.post(ApiEndpoints.presenceOffline(), const {});
  }

  /// Bulk presence lookup for a set of user ids — never call per-user.
  Future<List<PresenceInfo>> bulk(List<int> userIds) async {
    if (userIds.isEmpty) return const [];
    final decoded = await _client.post(ApiEndpoints.presenceBulk(), {
      'userIds': userIds,
    });
    final data = _data(decoded);
    final rows = (data['items'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((row) => PresenceInfo.fromApi(row.cast<String, dynamic>()))
        .toList();
  }
}
