import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/campaign_public_models.dart';

/// Persists public campaign list/detail for offline banner display.
class CampaignCacheService {
  static const _homeKey = 'campaign_home_banners_v1';
  static const _fetchedAtKey = 'campaign_home_banners_fetched_at_v1';
  static const _detailPrefix = 'campaign_detail_v1_';
  static const defaultTtl = Duration(minutes: 15);

  Future<void> saveHomeCampaigns(List<PublicCampaign> campaigns) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(campaigns.map((c) => c.toCacheJson()).toList());
    await prefs.setString(_homeKey, encoded);
    await prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<PublicCampaign>?> loadHomeCampaigns({Duration ttl = defaultTtl}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_homeKey);
    if (raw == null || raw.isEmpty) return null;

    final fetchedAtMs = prefs.getInt(_fetchedAtKey);
    if (fetchedAtMs != null) {
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
      );
      if (age > ttl) {
        // Still return stale data; caller decides refresh.
      }
    }

    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => PublicCampaign.fromCacheJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> isHomeCacheStale({Duration ttl = defaultTtl}) async {
    final prefs = await SharedPreferences.getInstance();
    final fetchedAtMs = prefs.getInt(_fetchedAtKey);
    if (fetchedAtMs == null) return true;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
    );
    return age > ttl;
  }

  Future<void> saveCampaignDetail(PublicCampaign campaign) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_detailPrefix${campaign.slug}',
      jsonEncode(campaign.toCacheJson()),
    );
  }

  Future<PublicCampaign?> loadCampaignDetail(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_detailPrefix$slug');
    if (raw == null) return null;
    try {
      return PublicCampaign.fromCacheJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeKey);
    await prefs.remove(_fetchedAtKey);
    final keys = prefs.getKeys().where((k) => k.startsWith(_detailPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
