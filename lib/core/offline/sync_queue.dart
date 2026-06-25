import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum SyncActionType {
  likePost,
  unlikePost,
  addComment,
  deleteComment,
  createPostDraft,
}

class SyncQueueItem {
  final String id; // uuid-style: "${type.name}_${timestamp}"
  final SyncActionType type;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  const SyncQueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      type: SyncActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncActionType.likePost,
      ),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      queuedAt: DateTime.parse(json['queuedAt'] as String),
    );
  }

  static String generateId(SyncActionType type) =>
      '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
}

/// Persists pending offline actions so they can be replayed when internet
/// returns. Wire up actual execution logic when you implement offline writes.
class SyncQueueService {
  static const _key = 'offline_sync_queue_v1';

  Future<List<SyncQueueItem>> getPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => SyncQueueItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> enqueue(SyncQueueItem item) async {
    final current = await getPendingActions();
    // Deduplicate: replace if same type+payload already queued.
    final updated = [
      ...current.where((e) => e.id != item.id),
      item,
    ];
    await _save(updated);
  }

  Future<void> dequeue(String id) async {
    final current = await getPendingActions();
    await _save(current.where((e) => e.id != id).toList());
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<int> pendingCount() async => (await getPendingActions()).length;

  Future<void> _save(List<SyncQueueItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
