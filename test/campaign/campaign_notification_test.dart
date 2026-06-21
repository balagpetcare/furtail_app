import 'package:bpa_app/features/campaign/data/models/campaign_public_models.dart';
import 'package:bpa_app/features/campaign/domain/campaign_notification_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CampaignNotificationCategory', () {
    test('maps booking types', () {
      expect(
        CampaignNotificationCategory.fromCode('campaign_booking_confirmed'),
        CampaignNotificationCategory.booking,
      );
    });

    test('maps reminder types', () {
      expect(
        CampaignNotificationCategory.fromCode('vaccine_reminder'),
        CampaignNotificationCategory.reminder,
      );
    });

    test('maps campaign types', () {
      expect(
        CampaignNotificationCategory.fromCode('campaign_new'),
        CampaignNotificationCategory.campaign,
      );
    });
  });

  group('PublicCampaignNotification FCM', () {
    test('parses actionUrl', () {
      final n = PublicCampaignNotification.fromFcm({
        'type': 'campaign_update',
        'title': 'Update',
        'body': 'Venue changed',
        'actionUrl': 'campaign/detail/test-slug',
      });
      expect(n.actionUrl, 'campaign/detail/test-slug');
    });
  });
}
