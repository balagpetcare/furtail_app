import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/smart_campaign/campaign_ab_variant.dart';

/// Stable A/B variant assignment per user + campaign test key.
class CampaignAbTestingService {
  static const _prefix = 'bpa_ab_variant_v1_';

  Future<CampaignAbVariant> assign({
    required String slug,
    required String? testKey,
    required List<String> variants,
    required String userSeed,
  }) async {
    final key = testKey ?? 'default_$slug';
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefix$key';
    final existing = prefs.getString(storageKey);
    if (existing != null && existing.isNotEmpty) {
      return CampaignAbVariant(testKey: key, variant: existing, slug: slug);
    }

    final pool = variants.isEmpty ? ['A', 'B'] : variants;
    final hash = '$userSeed|$key|$slug'.hashCode.abs();
    final variant = pool[hash % pool.length];
    await prefs.setString(storageKey, variant);
    return CampaignAbVariant(testKey: key, variant: variant, slug: slug);
  }

  Future<Map<String, CampaignAbVariant>> assignAll({
    required List<({String slug, String? testKey, List<String> variants})> items,
    required String userSeed,
  }) async {
    final out = <String, CampaignAbVariant>{};
    for (final item in items) {
      out[item.slug] = await assign(
        slug: item.slug,
        testKey: item.testKey,
        variants: item.variants,
        userSeed: userSeed,
      );
    }
    return out;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(k);
    }
  }

  /// Debug: export assignments
  Future<String> exportJson() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      map[k] = prefs.getString(k) ?? '';
    }
    return jsonEncode(map);
  }
}
