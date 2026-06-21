import 'package:furtail_app/features/campaign/data/services/campaign_ab_testing_service.dart';
import 'package:furtail_app/features/campaign/data/services/geo_targeting_service.dart';
import 'package:furtail_app/features/campaign/data/services/user_geo_preferences_service.dart';
import 'package:furtail_app/features/campaign/data/services/vaccination_reminder_engine.dart';
import 'package:furtail_app/features/campaign/data/models/campaign_public_models.dart';
import 'package:furtail_app/features/campaign/domain/smart_campaign/campaign_geo_target.dart';
import 'package:furtail_app/features/campaign/domain/smart_campaign/campaign_priority.dart';
import 'package:furtail_app/features/campaign/domain/smart_campaign/smart_campaign_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PublicCampaign _campaign({
  required String slug,
  CampaignPriority priority = CampaignPriority.medium,
  CampaignGeoTarget geo = const CampaignGeoTarget(),
}) {
  return PublicCampaign(
    id: 1,
    name: 'Test',
    slug: slug,
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 12, 31),
    pricingType: 'FREE',
    smartConfig: SmartCampaignConfig(priority: priority, geoTarget: geo),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('GeoTargetingService', () {
    test('sorts HIGH before LOW', () {
      final geo = GeoTargetingService(UserGeoPreferencesService());
      final sorted = geo.sortByPriority([
        _campaign(slug: 'low', priority: CampaignPriority.low),
        _campaign(slug: 'high', priority: CampaignPriority.high),
        _campaign(slug: 'med', priority: CampaignPriority.medium),
      ]);
      expect(sorted.first.slug, 'high');
      expect(sorted.last.slug, 'low');
    });

    test('filters by user district', () async {
      final prefs = UserGeoPreferencesService();
      await prefs.save(const UserGeoPreferences(district: 'Dhaka'));
      final geo = GeoTargetingService(prefs);
      final filtered = await geo.filterForUser([
        _campaign(
          slug: 'match',
          geo: const CampaignGeoTarget(districts: ['Dhaka']),
        ),
        _campaign(
          slug: 'miss',
          geo: const CampaignGeoTarget(districts: ['Chittagong']),
        ),
      ]);
      expect(filtered.length, 1);
      expect(filtered.first.slug, 'match');
    });
  });

  group('CampaignAbTestingService', () {
    test('assigns stable variant', () async {
      final ab = CampaignAbTestingService();
      final a = await ab.assign(
        slug: 'test',
        testKey: 'banner',
        variants: ['A', 'B'],
        userSeed: 'user-1',
      );
      final b = await ab.assign(
        slug: 'test',
        testKey: 'banner',
        variants: ['A', 'B'],
        userSeed: 'user-1',
      );
      expect(a.variant, b.variant);
    });
  });

  group('VaccinationReminderEngine offsets', () {
    test('rabies uses 30/7/0', () {
      expect(VaccinationReminderEngine.rabiesOffsets, [30, 7, 0]);
    });
    test('cat flu uses 7/3/0', () {
      expect(VaccinationReminderEngine.catFluOffsets, [7, 3, 0]);
    });
  });
}
