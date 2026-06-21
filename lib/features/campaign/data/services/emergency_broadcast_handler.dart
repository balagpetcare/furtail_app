import '../../../notifications/domain/notification_type.dart';
import '../../data/models/campaign_public_models.dart';

/// Handles admin emergency broadcasts (outbreak, extension, urgent notice).
class EmergencyBroadcastHandler {
  static const urgentTypes = {
    'emergency_broadcast',
    'urgent_vaccination_notice',
    'disease_outbreak_alert',
    'campaign_extension',
    'outbreak_alert',
  };

  static bool isEmergency(PublicCampaignNotification n) {
    final t = n.type.toLowerCase();
    return urgentTypes.contains(t) || t.contains('outbreak') || t.contains('urgent');
  }

  static AppNotificationType notificationType(PublicCampaignNotification n) {
    final t = n.type.toLowerCase();
    if (t.contains('outbreak') || t == 'emergency_broadcast') {
      return AppNotificationType.emergency;
    }
    if (t.contains('extension') || t.contains('urgent')) {
      return AppNotificationType.announcement;
    }
    return AppNotificationType.campaignUpdate;
  }

  static String? actionUrl(PublicCampaignNotification n) {
    if (n.actionUrl != null && n.actionUrl!.isNotEmpty) return n.actionUrl;
    if (n.campaignSlug != null) return 'campaign/detail/${n.campaignSlug}';
    return '/campaign';
  }
}
