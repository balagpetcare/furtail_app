import 'dart:convert';

import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CacheBox<T> {
  final DateTime expiresAt;
  final List<T> items;
  const _CacheBox({required this.expiresAt, required this.items});
}

class LocationRepository {
  final ApiClient _client;
  LocationRepository(this._client);

  static const Duration _ttl = Duration(hours: 12);
  static const String _storagePrefix = 'location_master_cache_v1:';
  final Map<String, _CacheBox<dynamic>> _memory = {};

  String _key(String level, Map<String, dynamic> params) {
    final entries = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final raw = entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$level?$raw';
  }

  bool _isFresh(DateTime expiresAt) => expiresAt.isAfter(DateTime.now());

  Future<List<T>> _readStorage<T>(
    String key,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix$key');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAtRaw = decoded['expiresAt']?.toString();
      final items = (decoded['items'] as List?) ?? const [];
      final expiresAt = DateTime.tryParse(expiresAtRaw ?? '');
      if (expiresAt == null || !_isFresh(expiresAt)) return const [];
      return items
          .whereType<Map>()
          .map((e) => parser(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeStorage(String key, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'expiresAt': DateTime.now().add(_ttl).toIso8601String(),
      'items': rows,
    };
    await prefs.setString('$_storagePrefix$key', jsonEncode(payload));
  }

  Future<List<Map<String, dynamic>>> _fetchRows(String endpoint) async {
    final res = await _client.get(endpoint, auth: true);
    final list = (res is Map && res['data'] is List)
        ? (res['data'] as List)
        : (res is Map && res['items'] is List)
            ? (res['items'] as List)
            : const [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<T>> _cachedList<T>({
    required String key,
    required Future<List<Map<String, dynamic>>> Function() network,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    final inMemory = _memory[key];
    if (inMemory != null && _isFresh(inMemory.expiresAt)) {
      return inMemory.items.cast<T>();
    }

    try {
      final rows = await network();
      final parsed = rows.map(parser).toList();
      _memory[key] = _CacheBox<dynamic>(expiresAt: DateTime.now().add(_ttl), items: parsed);
      await _writeStorage(key, rows);
      return parsed;
    } catch (_) {
      final fromStorage = await _readStorage<T>(key, parser);
      if (fromStorage.isNotEmpty) {
        _memory[key] = _CacheBox<dynamic>(
          expiresAt: DateTime.now().add(const Duration(minutes: 30)),
          items: fromStorage,
        );
      }
      return fromStorage;
    }
  }

  Future<List<BdDivision>> getDivisions({String locale = 'en', String? q}) {
    final key = _key('divisions', {'locale': locale, 'q': q ?? ''});
    return _cachedList<BdDivision>(
      key: key,
      network: () => _fetchRows(ApiEndpoints.locationMasterDivisions(locale: locale, q: q)),
      parser: BdDivision.fromJson,
    );
  }

  Future<List<BdDistrict>> getDistricts({
    required int divisionId,
    String locale = 'en',
    String? q,
  }) {
    final key = _key('districts', {
      'divisionId': divisionId,
      'locale': locale,
      'q': q ?? '',
    });
    return _cachedList<BdDistrict>(
      key: key,
      network: () => _fetchRows(
        ApiEndpoints.locationMasterDistricts(
          divisionId: divisionId,
          locale: locale,
          q: q,
        ),
      ),
      parser: BdDistrict.fromJson,
    );
  }

  Future<List<BdUpazila>> getUpazilas({
    required int districtId,
    String locale = 'en',
    String? q,
  }) {
    final key = _key('upazilas', {
      'districtId': districtId,
      'locale': locale,
      'q': q ?? '',
    });
    return _cachedList<BdUpazila>(
      key: key,
      network: () => _fetchRows(
        ApiEndpoints.locationMasterUpazilas(
          districtId: districtId,
          locale: locale,
          q: q,
        ),
      ),
      parser: BdUpazila.fromJson,
    );
  }

  Future<List<BdUnion>> getUnions({
    required int upazilaId,
    String locale = 'en',
    String? q,
  }) {
    final key = _key('unions', {
      'upazilaId': upazilaId,
      'locale': locale,
      'q': q ?? '',
    });
    return _cachedList<BdUnion>(
      key: key,
      network: () => _fetchRows(
        ApiEndpoints.locationMasterUnions(
          upazilaId: upazilaId,
          locale: locale,
          q: q,
        ),
      ),
      parser: BdUnion.fromJson,
    );
  }

  Future<void> prefetchForDivision(int divisionId) async {
    final districts = await getDistricts(divisionId: divisionId);
    for (final district in districts.take(5)) {
      // Prefetch top branches to keep startup responsive.
      final upazilas = await getUpazilas(districtId: district.id);
      for (final upazila in upazilas.take(3)) {
        await getUnions(upazilaId: upazila.id);
      }
    }
  }
}

