import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifications/domain/notification_type.dart';
import '../../../notifications/presentation/providers/notification_controller.dart';
import '../../data/models/campaign_public_models.dart';
import '../../domain/campaign_notification_category.dart';
import '../../domain/smart_campaign/campaign_geo_target.dart';
import '../../domain/smart_campaign/smart_campaign_config.dart';
import '../../presentation/providers/smart_campaign_providers.dart';
import 'emergency_broadcast_handler.dart';
import 'smart_campaign_engine.dart';
import 'user_geo_preferences_service.dart';

/// Bridges campaign FCM payloads → geo-filtered local display + deep links.
class CampaignNotificationService {
  CampaignNotificationService(this._ref, this._engine, this._geoPrefs);

  final Ref _ref;
  final SmartCampaignEngine _engine;
  final UserGeoPreferencesService _geoPrefs;

  static AppNotificationType typeForPayload(PublicCampaignNotification n) {
    if (EmergencyBroadcastHandler.isEmergency(n)) {
      return EmergencyBroadcastHandler.notificationType(n);
    }
    final cat = CampaignNotificationCategory.fromCode(n.type);
    switch (cat) {
      case CampaignNotificationCategory.booking:
        return AppNotificationType.campaignBookingConfirmed;
      case CampaignNotificationCategory.reminder:
        return AppNotificationType.campaignReminder;
      case CampaignNotificationCategory.campaign:
        if (n.type.contains('cancel')) return AppNotificationType.campaignCancelled;
        if (n.type.contains('update')) return AppNotificationType.campaignUpdate;
        return AppNotificationType.campaignNew;
    }
  }

  String? actionUrlFor(PublicCampaignNotification n) {
    if (EmergencyBroadcastHandler.isEmergency(n)) {
      return EmergencyBroadcastHandler.actionUrl(n);
    }
    if (n.actionUrl != null && n.actionUrl!.isNotEmpty) return n.actionUrl;
    if (n.campaignSlug != null && n.campaignSlug!.isNotEmpty) {
      return 'campaign/detail/${n.campaignSlug}';
    }
    return null;
  }

  static bool isCampaignFcmPayload(Map<String, dynamic> data) {
    final domain = data['domain']?.toString().toLowerCase() ?? '';
    if (domain == 'campaign') return true;
    if (data['campaignSlug'] != null || data['campaignId'] != null) return true;
    final type = data['type']?.toString().toLowerCase() ?? '';
    if (EmergencyBroadcastHandler.urgentTypes.contains(type)) return true;
    return type.contains('campaign') ||
        type.contains('booking') ||
        type.contains('vaccination');
  }

  Future<void> showLocal(PublicCampaignNotification notification) async {
    await _ref.read(notificationControllerProvider.notifier).showTyped(
          type: typeForPayload(notification),
          title: notification.title,
          body: notification.body,
          actionUrl: actionUrlFor(notification),
        );
  }

  Future<void> handleFcmData(Map<String, dynamic> data) async {
    final notification = PublicCampaignNotification.fromFcm(data);
    final slug = notification.campaignSlug;
    if (slug != null &&
        slug.isNotEmpty &&
        !EmergencyBroadcastHandler.isEmergency(notification)) {
      final user = await _geoPrefs.load();
      if (user.isConfigured) {
        final geoRaw = data['geoTargets'];
        if (geoRaw is Map) {
          final target = CampaignGeoTarget.fromJson(Map<String, dynamic>.from(geoRaw));
          final synthetic = PublicCampaign(
            id: notification.campaignId ?? 0,
            name: notification.title,
            slug: slug,
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 30)),
            pricingType: 'FREE',
            smartConfig: SmartCampaignConfig(geoTarget: target),
          );
          final ok = await _engine.shouldNotifyUser(synthetic);
          if (!ok) return;
        }
      }
    }
    await showLocal(notification);
  }
}

final campaignNotificationServiceProvider = Provider<CampaignNotificationService>((ref) {
  return CampaignNotificationService(
    ref,
    ref.read(smartCampaignEngineProvider),
    ref.read(userGeoPreferencesServiceProvider),
  );
});
