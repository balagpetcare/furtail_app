import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notification_type.dart';

/// Android notification channels mapped to [AppNotificationType].
abstract final class NotificationChannels {
  static const String _prefix = 'bpa_';

  /// Dedicated channel for all social interactions.
  static const String socialChannelId = 'social_notifications';

  static String idFor(AppNotificationType type) {
    if (type.isSocial) return socialChannelId;
    return '$_prefix${type.code}';
  }

  static List<AndroidNotificationChannel> androidChannels() {
    return [
      _channel(
        AppNotificationType.emergency,
        'Emergency',
        'Critical safety and urgent alerts',
        Importance.max,
      ),
      _channel(
        AppNotificationType.campaignReminder,
        'Campaign reminders',
        'Vaccination campaign schedules and events',
        Importance.high,
      ),
      _channel(
        AppNotificationType.campaignNew,
        'Campaign alerts',
        'New and updated vaccination campaigns',
        Importance.high,
      ),
      _channel(
        AppNotificationType.campaignBookingConfirmed,
        'Booking updates',
        'Vaccination booking confirmations',
        Importance.high,
      ),
      _channel(
        AppNotificationType.campaignUpdate,
        'Campaign updates',
        'Schedule and venue changes',
        Importance.defaultImportance,
      ),
      _channel(
        AppNotificationType.campaignCancelled,
        'Campaign cancellations',
        'Cancelled campaigns and bookings',
        Importance.high,
      ),
      _channel(
        AppNotificationType.vaccineReminder,
        'Vaccine reminders',
        'Upcoming pet vaccination due dates',
        Importance.high,
      ),
      _channel(
        AppNotificationType.donationUpdate,
        'Donation updates',
        'Fundraising and donation activity',
        Importance.defaultImportance,
      ),
      _channel(
        AppNotificationType.communityActivity,
        'Community',
        'Community posts and activity',
        Importance.defaultImportance,
      ),
      _channel(
        AppNotificationType.comment,
        'Comments',
        'Comments on your posts',
        Importance.defaultImportance,
      ),
      _channel(
        AppNotificationType.like,
        'Likes',
        'Likes on your content',
        Importance.low,
      ),
      _channel(
        AppNotificationType.follow,
        'Follows',
        'New followers',
        Importance.defaultImportance,
      ),
      _channel(
        AppNotificationType.announcement,
        'Announcements',
        'News and platform announcements',
        Importance.high,
      ),
      _channel(
        AppNotificationType.general,
        'General',
        'Other notifications',
        Importance.defaultImportance,
      ),
      // Social interactions channel (shared by all social types)
      AndroidNotificationChannel(
        socialChannelId,
        'Social notifications',
        description: 'Friend requests, follows, and pet interactions',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    ];
  }

  static AndroidNotificationChannel _channel(
    AppNotificationType type,
    String name,
    String description,
    Importance importance,
  ) {
    return AndroidNotificationChannel(
      idFor(type),
      name,
      description: description,
      importance: importance,
      playSound: true,
      enableVibration: importance.index >= Importance.high.index,
    );
  }
}
