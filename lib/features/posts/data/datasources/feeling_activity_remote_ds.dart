import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/features/posts/data/models/feeling_activity_model.dart';

/// Remote data source for feeling/activity items.
///
/// Fetches from the backend API with a local cache fallback.
/// If the API is unreachable, returns cached data or the hardcoded fallback.
class FeelingActivityRemoteDs {
  final SecureStorageService _secureStorage;

  FeelingActivityRemoteDs([SecureStorageService? secureStorage])
    : _secureStorage = secureStorage ?? SecureStorageService();

  Future<String?> _token() => _secureStorage.accessToken;

  Future<Map<String, String>> _authHeaders() async {
    final t = await _token();
    return <String, String>{
      if (t != null) 'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    };
  }

  /// Fetches active feeling/activity items from the backend.
  /// Supports optional filters: type, category, petSpecific, q.
  Future<List<FeelingActivityItem>> fetch({
    String? type,
    String? category,
    bool? petSpecific,
    String? q,
  }) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (category != null) params['category'] = category;
    if (petSpecific != null) params['petSpecific'] = petSpecific.toString();
    if (q != null && q.isNotEmpty) params['q'] = q;

    final uri = Uri.parse(
      ApiEndpoints.feelingActivities,
    ).replace(queryParameters: params.isNotEmpty ? params : null);

    final res = await http.get(uri, headers: await _authHeaders());

    if (res.statusCode != 200) {
      throw Exception(
        'Feeling/activity fetch failed (${res.statusCode}): ${res.body}',
      );
    }

    final decoded = jsonDecode(res.body);
    final list = (decoded['data'] as List?) ?? const [];

    // Cache the raw response for offline fallback
    await _cacheRaw(res.body);

    return list
        .map((e) => FeelingActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns cached items, or the hardcoded fallback if no cache exists.
  Future<List<FeelingActivityItem>> getCached() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return FeelingActivityItem.all; // hardcoded fallback
    }
    try {
      final decoded = jsonDecode(raw);
      final list = (decoded['data'] as List?) ?? [];
      return list
          .map((e) => FeelingActivityItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return FeelingActivityItem.all;
    }
  }

  Future<void> _cacheRaw(String raw) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_cacheKey, raw);
  }

  static const String _cacheKey = 'feeling_activity_cache';
}
