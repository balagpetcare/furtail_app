import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local caching for reference data (species/breeds/divisions/districts/...)
/// with a TTL and explicit refresh support. Cached data is a convenience
/// layer only — it is never the source of truth: every read still goes
/// through the API when the cache is empty, stale, or a refresh is
/// requested, and callers can always force a network refresh.
///
/// Two tiers: an in-memory tier (survives for the app session, cleared on
/// cold start) and a SharedPreferences-backed tier (survives app restarts)
/// for the same TTL.
class ReferenceDataCache {
  ReferenceDataCache({Duration? ttl, SharedPreferences? prefs})
    : _ttl = ttl ?? const Duration(hours: 6),
      _prefs = prefs;

  final Duration _ttl;
  SharedPreferences? _prefs;
  final Map<String, _CacheEntry> _memory = {};

  static const _prefsPrefix = 'ref_data_cache::';

  Future<SharedPreferences> _prefsInstance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Returns cached data for [key] if present and not stale; otherwise calls
  /// [fetch], caches the result, and returns it. Pass `forceRefresh: true`
  /// to bypass the cache and always hit the network (used by pull-to-
  /// refresh / retry actions), which also repopulates the cache.
  Future<T> getOrFetch<T>({
    required String key,
    required Future<T> Function() fetch,
    required Map<String, dynamic> Function(T value) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final memoryHit = _memory[key];
      if (memoryHit != null && !memoryHit.isStale(_ttl)) {
        return memoryHit.value as T;
      }
      final persisted = await _readPersisted<T>(key, fromJson);
      if (persisted != null) {
        _memory[key] = _CacheEntry(persisted.value, persisted.cachedAt);
        if (DateTime.now().difference(persisted.cachedAt) <= _ttl) {
          return persisted.value;
        }
      }
    }

    try {
      final value = await fetch();
      final now = DateTime.now();
      _memory[key] = _CacheEntry(value, now);
      unawaited(_writePersisted(key, value, now, toJson));
      return value;
    } catch (error) {
      // Network/API failure: fall back to a stale cached value if we have
      // one, rather than surfacing a hard failure for data that rarely
      // changes. The cache is never treated as authoritative when a fresh
      // fetch succeeds — this fallback only applies on failure.
      final memoryFallback = _memory[key];
      if (memoryFallback != null) return memoryFallback.value as T;
      final persistedFallback = await _readPersisted<T>(key, fromJson);
      if (persistedFallback != null) return persistedFallback.value;
      rethrow;
    }
  }

  Future<_PersistedEntry<T>?> _readPersisted<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    try {
      final prefs = await _prefsInstance();
      final raw = prefs.getString('$_prefsPrefix$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAtMs = decoded['cachedAt'] as int?;
      final payload = decoded['payload'];
      if (cachedAtMs == null || payload == null) return null;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
      final value = fromJson(Map<String, dynamic>.from(payload as Map));
      return _PersistedEntry(value, cachedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersisted<T>(
    String key,
    T value,
    DateTime cachedAt,
    Map<String, dynamic> Function(T value) toJson,
  ) async {
    try {
      final prefs = await _prefsInstance();
      final encoded = jsonEncode({
        'cachedAt': cachedAt.millisecondsSinceEpoch,
        'payload': toJson(value),
      });
      await prefs.setString('$_prefsPrefix$key', encoded);
    } catch (_) {
      // Persistence is best-effort; the in-memory tier still works.
    }
  }

  /// Drops the cached value for [key] (both tiers) so the next read always
  /// hits the network.
  Future<void> invalidate(String key) async {
    _memory.remove(key);
    try {
      final prefs = await _prefsInstance();
      await prefs.remove('$_prefsPrefix$key');
    } catch (_) {}
  }

  void clearMemory() => _memory.clear();
}

class _CacheEntry {
  _CacheEntry(this.value, this.cachedAt);
  final dynamic value;
  final DateTime cachedAt;
  bool isStale(Duration ttl) => DateTime.now().difference(cachedAt) > ttl;
}

class _PersistedEntry<T> {
  _PersistedEntry(this.value, this.cachedAt);
  final T value;
  final DateTime cachedAt;
}
