import '../../data/models/campaign_public_models.dart';
import '../../domain/smart_campaign/campaign_geo_target.dart';
import 'user_geo_preferences_service.dart';

/// Filters and sorts campaigns by geo relevance and priority.
class GeoTargetingService {
  GeoTargetingService(this._geoPrefs);

  final UserGeoPreferencesService _geoPrefs;

  Future<List<PublicCampaign>> filterForUser(List<PublicCampaign> campaigns) async {
    final user = await _geoPrefs.load();
    if (!user.isConfigured) return campaigns;

    return campaigns.where((c) => _matchesUser(c, user)).toList();
  }

  bool shouldDeliverNotification(PublicCampaign campaign, UserGeoPreferences user) {
    if (campaign.smartConfig.geoTarget.isEmpty) return true;
    if (!user.isConfigured) return false;
    return _matchesUser(campaign, user);
  }

  bool _matchesUser(PublicCampaign campaign, UserGeoPreferences user) {
    final target = campaign.smartConfig.geoTarget;
    if (target.isEmpty) return true;

    final city = user.city?.toLowerCase().trim() ?? '';
    final district = user.district?.toLowerCase().trim() ?? '';
    final area = user.serviceArea?.toLowerCase().trim() ?? '';

    if (target.cities.isNotEmpty && city.isNotEmpty) {
      if (target.cities.any((c) => c.toLowerCase() == city)) return true;
    }
    if (target.districts.isNotEmpty && district.isNotEmpty) {
      if (target.districts.any((d) => d.toLowerCase() == district)) return true;
    }
    if (target.serviceAreas.isNotEmpty && area.isNotEmpty) {
      if (target.serviceAreas.any((a) => a.toLowerCase() == area)) return true;
    }

    // Partial match on location names when user has not set granular prefs
    if (city.isEmpty && district.isEmpty && area.isEmpty) return false;

    for (final loc in campaign.locations) {
      final name = loc.name.toLowerCase();
      final addr = (loc.address ?? '').toLowerCase();
      if (target.cities.any((c) => name.contains(c.toLowerCase()) || addr.contains(c.toLowerCase()))) {
        return true;
      }
      if (target.districts.any((d) => name.contains(d.toLowerCase()) || addr.contains(d.toLowerCase()))) {
        return true;
      }
      if (target.serviceAreas.any((a) => name.contains(a.toLowerCase()) || addr.contains(a.toLowerCase()))) {
        return true;
      }
    }
    return false;
  }

  List<PublicCampaign> sortByPriority(List<PublicCampaign> campaigns) {
    final sorted = List<PublicCampaign>.from(campaigns);
    sorted.sort((a, b) {
      final pa = a.smartConfig.priority.sortOrder;
      final pb = b.smartConfig.priority.sortOrder;
      if (pa != pb) return pa.compareTo(pb);
      return a.startDate.compareTo(b.startDate);
    });
    return sorted;
  }
}
