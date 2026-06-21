import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/campaign_performance_metrics.dart';

/// Local campaign funnel metrics for dashboard + A/B analysis.
class CampaignPerformanceTracker {
  static const _prefix = 'bpa_campaign_perf_v1_';

  Future<CampaignPerformanceMetrics> load(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$slug');
    if (raw == null) return CampaignPerformanceMetrics(slug: slug);
    try {
      return CampaignPerformanceMetrics.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return CampaignPerformanceMetrics(slug: slug);
    }
  }

  Future<void> recordView(String slug, {String? abVariant}) async {
    final m = await load(slug);
    await _save(CampaignPerformanceMetrics(
      slug: slug,
      views: m.views + 1,
      clicks: m.clicks,
      bookings: m.bookings,
      revenue: m.revenue,
      abVariant: abVariant ?? m.abVariant,
    ));
  }

  Future<void> recordClick(String slug, {String? abVariant}) async {
    final m = await load(slug);
    await _save(CampaignPerformanceMetrics(
      slug: slug,
      views: m.views,
      clicks: m.clicks + 1,
      bookings: m.bookings,
      revenue: m.revenue,
      abVariant: abVariant ?? m.abVariant,
    ));
  }

  Future<void> recordBooking(String slug, {num revenue = 0, String? abVariant}) async {
    final m = await load(slug);
    await _save(CampaignPerformanceMetrics(
      slug: slug,
      views: m.views,
      clicks: m.clicks,
      bookings: m.bookings + 1,
      revenue: m.revenue + revenue,
      abVariant: abVariant ?? m.abVariant,
    ));
  }

  Future<void> recordPayment(String slug, {required num amount, String? abVariant}) async {
    final m = await load(slug);
    await _save(CampaignPerformanceMetrics(
      slug: slug,
      views: m.views,
      clicks: m.clicks,
      bookings: m.bookings,
      revenue: m.revenue + amount,
      abVariant: abVariant ?? m.abVariant,
    ));
  }

  Future<List<CampaignPerformanceMetrics>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <CampaignPerformanceMetrics>[];
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      final raw = prefs.getString(k);
      if (raw == null) continue;
      try {
        out.add(CampaignPerformanceMetrics.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        ));
      } catch (_) {}
    }
    return out;
  }

  Future<void> _save(CampaignPerformanceMetrics m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${m.slug}', jsonEncode(m.toJson()));
  }
}
