import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notification_type.dart';

/// Android notification channels mapped to [AppNotificationType].
abstract final class NotificationChannels {
  static const String _prefix = 'bpa_';

  /// Dedicated channel for all social interactions.
  static const String socialChannelId = 'social_notifications';
  static const String uploadProgressChannelId = 'upload_progress';
  static const String uploadAlertChannelId = 'upload_alerts';

  /// Dedicated high-importance channel for 1:1 direct messages. Stable ID —
  /// must match `channelIdFor()` in the backend's push-delivery.service.ts,
  /// since a push whose `channelId` doesn't match an already-created
  /// channel silently falls back to the OS default channel (no custom
  /// sound/importance). Android notification channels are immutable after
  /// first creation on a given install: if this channel was ever created
  /// with different settings on a dev device, uninstall/reinstall (or
  /// Settings > Apps > Furtail > Notifications > Messages) is required to
  /// see updated settings — code changes alone cannot retroactively change
  /// a channel a user already has.
  static const String messagesChannelId = 'furtail_messages';

  static String idFor(AppNotificationType type) {
    if (type == AppNotificationType.message) return messagesChannelId;
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
      // Direct messages — high importance, sound + vibration, so a new
      // message is never mistaken for a low-priority background alert.
      AndroidNotificationChannel(
        messagesChannelId,
        'Messages',
        description: 'New direct messages from other Furtail users',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
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
      AndroidNotificationChannel(
        uploadProgressChannelId,
        'Upload progress',
        description: 'Ongoing post and video upload progress',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
      AndroidNotificationChannel(
        uploadAlertChannelId,
        'Upload alerts',
        description: 'Upload completion and processing alerts',
        importance: Importance.high,
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
