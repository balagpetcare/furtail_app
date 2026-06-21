import '../../data/models/campaign_countdown.dart';
import '../repositories/campaign_repository.dart';

/// Fetches and caches countdown data for campaign banners.
class CampaignCountdownService {
  CampaignCountdownService(this._repo);

  final CampaignRepository _repo;
  final _cache = <String, CampaignCountdownSnapshot>{};

  Future<CampaignCountdownSnapshot?> forSlug(String slug) async {
    if (_cache.containsKey(slug)) return _cache[slug];
    try {
      final snap = await _repo.fetchCampaignCountdown(slug);
      _cache[slug] = snap;
      return snap;
    } catch (_) {
      return null;
    }
  }

  void invalidate(String slug) => _cache.remove(slug);
  void clear() => _cache.clear();
}
