import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/secure_storage_service.dart';
import '../../data/models/campaign_public_models.dart';
import 'campaign_ab_testing_service.dart';
import 'campaign_countdown_service.dart';
import 'geo_targeting_service.dart';
import 'user_geo_preferences_service.dart';

/// Central orchestrator for Smart Campaign Engine v2.
class SmartCampaignEngine {
  SmartCampaignEngine({
    required GeoTargetingService geoTargeting,
    required CampaignAbTestingService abTesting,
    required CampaignCountdownService countdown,
    required UserGeoPreferencesService geoPrefs,
  }) : _geoTargeting = geoTargeting,
       _abTesting = abTesting,
       _countdown = countdown,
       _geoPrefs = geoPrefs;

  final GeoTargetingService _geoTargeting;
  final CampaignAbTestingService _abTesting;
  final CampaignCountdownService _countdown;
  final UserGeoPreferencesService _geoPrefs;

  /// Filter geo, assign A/B variants, sort by priority for homepage.
  Future<List<PublicCampaign>> prepareHomeCampaigns(
    List<PublicCampaign> raw,
  ) async {
    var campaigns = await _geoTargeting.filterForUser(raw);
    campaigns = _geoTargeting.sortByPriority(campaigns);

    final userSeed = await _userSeed();
    final withVariants = <PublicCampaign>[];
    for (final c in campaigns) {
      final variant = await _abTesting.assign(
        slug: c.slug,
        testKey: c.smartConfig.abTestKey,
        variants: c.smartConfig.abVariants,
        userSeed: userSeed,
      );
      withVariants.add(c.copyWith(abVariant: variant));
    }
    return withVariants;
  }

  Future<String> _userSeed() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = await SecureStorageService().accessToken;
    return prefs.getString('userId') ??
        prefs.getString('userPhone') ??
        accessToken ??
        'guest';
  }

  CampaignCountdownService get countdown => _countdown;
  UserGeoPreferencesService get geoPrefs => _geoPrefs;

  Future<bool> shouldNotifyUser(PublicCampaign campaign) async {
    final user = await _geoPrefs.load();
    return _geoTargeting.shouldDeliverNotification(campaign, user);
  }
}
