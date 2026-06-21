import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/smart_campaign/campaign_geo_target.dart';

/// Persists user city / district / service area for geo-targeted notifications.
class UserGeoPreferencesService {
  static const _key = 'bpa_campaign_geo_prefs_v1';

  Future<UserGeoPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const UserGeoPreferences();
    try {
      return UserGeoPreferences.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const UserGeoPreferences();
    }
  }

  Future<void> save(UserGeoPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(prefs.toJson()));
  }
}
