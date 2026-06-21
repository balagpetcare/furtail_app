import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/campaign_countdown.dart';
import '../../data/models/campaign_performance_metrics.dart';
import '../../data/services/campaign_ab_testing_service.dart';
import '../../data/services/campaign_countdown_service.dart';
import '../../data/services/campaign_performance_tracker.dart';
import '../../data/services/geo_targeting_service.dart';
import '../../data/services/smart_campaign_engine.dart';
import '../../data/services/user_geo_preferences_service.dart';
import '../../data/services/vaccination_reminder_engine.dart';
import '../../domain/smart_campaign/campaign_geo_target.dart';
import '../providers/campaign_providers.dart';
import '../../../notifications/presentation/providers/notification_controller.dart';

final userGeoPreferencesServiceProvider = Provider<UserGeoPreferencesService>((ref) {
  return UserGeoPreferencesService();
});

final geoTargetingServiceProvider = Provider<GeoTargetingService>((ref) {
  return GeoTargetingService(ref.read(userGeoPreferencesServiceProvider));
});

final campaignAbTestingServiceProvider = Provider<CampaignAbTestingService>((ref) {
  return CampaignAbTestingService();
});

final campaignCountdownServiceProvider = Provider<CampaignCountdownService>((ref) {
  return CampaignCountdownService(ref.read(campaignRepositoryProvider));
});

final campaignPerformanceTrackerProvider = Provider<CampaignPerformanceTracker>((ref) {
  return CampaignPerformanceTracker();
});

final smartCampaignEngineProvider = Provider<SmartCampaignEngine>((ref) {
  return SmartCampaignEngine(
    geoTargeting: ref.read(geoTargetingServiceProvider),
    abTesting: ref.read(campaignAbTestingServiceProvider),
    countdown: ref.read(campaignCountdownServiceProvider),
    geoPrefs: ref.read(userGeoPreferencesServiceProvider),
  );
});

final userGeoPreferencesProvider = FutureProvider<UserGeoPreferences>((ref) async {
  return ref.read(userGeoPreferencesServiceProvider).load();
});

final campaignCountdownProvider =
    FutureProvider.family<CampaignCountdownSnapshot?, String>((ref, slug) async {
  return ref.read(smartCampaignEngineProvider).countdown.forSlug(slug);
});

final campaignPerformanceProvider =
    FutureProvider.family<CampaignPerformanceMetrics, String>((ref, slug) async {
  return ref.read(campaignPerformanceTrackerProvider).load(slug);
});

final allCampaignPerformanceProvider = FutureProvider<List<CampaignPerformanceMetrics>>((ref) async {
  return ref.read(campaignPerformanceTrackerProvider).loadAll();
});

/// Syncs smart vaccination reminders when records change.
final smartVaccinationReminderSyncProvider = FutureProvider<void>((ref) async {
  await ref.read(notificationControllerProvider.future);
  final records = await ref.read(vaccinationRecordsProvider.future);
  final notifications = ref.read(notificationServiceProvider);
  final engine = VaccinationReminderEngine(notifications);
  await engine.syncRecords(records);
});
