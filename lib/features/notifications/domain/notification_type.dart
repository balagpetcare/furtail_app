/// App notification categories (push + local).
enum AppNotificationType {
  campaignReminder('campaign_reminder'),
  campaignNew('campaign_new'),
  campaignBookingConfirmed('campaign_booking_confirmed'),
  campaignUpdate('campaign_update'),
  campaignCancelled('campaign_cancelled'),
  vaccineReminder('vaccine_reminder'),
  donationUpdate('donation_update'),
  communityActivity('community_activity'),
  comment('comment'),
  like('like'),
  follow('follow'),
  announcement('announcement'),
  emergency('emergency'),
  /// Generic push when server omits a known type.
  general('general');

  const AppNotificationType(this.code);

  final String code;

  static AppNotificationType fromCode(String? raw) {
    if (raw == null || raw.isEmpty) return AppNotificationType.general;
    final normalized = raw.trim().toLowerCase();
    for (final t in AppNotificationType.values) {
      if (t.code == normalized) return t;
    }
    switch (normalized) {
      case 'campaign':
        return AppNotificationType.campaignNew;
      case 'campaign_booking_confirmed':
      case 'booking_confirmed':
        return AppNotificationType.campaignBookingConfirmed;
      case 'campaign_update':
        return AppNotificationType.campaignUpdate;
      case 'campaign_cancelled':
        return AppNotificationType.campaignCancelled;
      case 'campaign_new':
        return AppNotificationType.campaignNew;
      case 'vaccine':
      case 'vaccination':
        return AppNotificationType.vaccineReminder;
      case 'donation':
        return AppNotificationType.donationUpdate;
      case 'community':
        return AppNotificationType.communityActivity;
      default:
        return AppNotificationType.general;
    }
  }
}
