import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post_model.dart';

// TODO(Phase 2): Migrate feed cache from SharedPreferences JSON to a proper
// local database (Drift or Isar) for:
//   • Reliable large-payload storage (SharedPreferences XML has size limits)
//   • Individual post update/delete without full re-serialization
//   • Efficient cursor-based pagination queries
//   • Indexed lookups by postId, authorId, createdAt
// Migration guide: https://drift.simonbinder.eu / https://isar.dev

/// Persists the raw home-feed API response for offline-first display.
///
/// **Phase 1** – SharedPreferences JSON store.
///
/// Auth tokens are never stored here; they live only in [LocalStorage].
///
/// TTL contract
/// ────────────
/// [defaultTtl] is a **background-refresh hint only**.  It is used by
/// [isCacheStale] to decide whether to trigger a silent network refresh while
/// online.  It never gates whether cached data can be *displayed*: [loadFeed]
/// always returns whatever is in the cache, regardless of age.  This ensures
/// the user always sees content when offline, even if the cache is weeks old.
class FeedCacheService {
  static const _rawJsonKey = 'feed_cache_raw_v2';
  static const _fetchedAtKey = 'feed_cache_fetched_at_v2';

  /// Controls when a background refresh is triggered while online.
  /// Does NOT control whether the cache is shown to the user.
  static const defaultTtl = Duration(hours: 2);

  /// Saves the raw JSON body returned by the feed API endpoint.
  /// Never call this with data that includes auth credentials.
  Future<void> saveRawJson(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rawJsonKey, rawJson);
    await prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Loads and parses the cached feed.
  ///
  /// Returns `null` only if the cache is completely empty.  Corrupted or
  /// partially-incompatible data is handled defensively:
  /// - A corrupt top-level JSON blob is cleared and `null` is returned.
  /// - Individual items that fail to parse are **skipped** so the rest of
  ///   the feed still renders (graceful degradation, not all-or-nothing).
  Future<List<PostModel>?> loadFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rawJsonKey);
    if (raw == null || raw.isEmpty) return null;

    List? list;
    try {
      final decoded = jsonDecode(raw);
      list = (decoded['data'] as List?) ?? const [];
    } catch (_) {
      // Top-level JSON is corrupt. Clear it so we don't keep re-parsing.
      await _clearCorrupt(prefs);
      return null;
    }

    final results = <PostModel>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        results.add(PostModel.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip this item — model schema may have changed since it was cached.
        // The rest of the feed is still valid.
      }
    }
    return results; // may be empty list (valid, no posts)
  }

  /// Returns `true` when the cache is older than [ttl].
  ///
  /// Use this to decide whether to trigger a background refresh, **not**
  /// whether to show the cache.  Offline users should always see the cache.
  Future<bool> isCacheStale({Duration ttl = defaultTtl}) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_fetchedAtKey);
    if (ms == null) return true;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms)) >
        ttl;
  }

  Future<DateTime?> lastFetchedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_fetchedAtKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rawJsonKey);
    await prefs.remove(_fetchedAtKey);
  }

  Future<void> _clearCorrupt(SharedPreferences prefs) async {
    await prefs.remove(_rawJsonKey);
    // Keep _fetchedAtKey so isCacheStale correctly returns true next time.
  }
}
