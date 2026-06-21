/// High-level notification categories for the vaccination campaign module.
enum CampaignNotificationCategory {
  campaign('campaign'),
  booking('booking'),
  reminder('reminder');

  const CampaignNotificationCategory(this.code);
  final String code;

  static CampaignNotificationCategory fromCode(String? raw) {
    if (raw == null || raw.isEmpty) return CampaignNotificationCategory.campaign;
    final n = raw.trim().toLowerCase();
    for (final c in CampaignNotificationCategory.values) {
      if (c.code == n) return c;
    }
    switch (n) {
      case 'campaign_new':
      case 'campaign_update':
      case 'campaign_cancelled':
      case 'campaign_starting_soon':
      case 'campaign_today':
      case 'campaign_nearby':
        return CampaignNotificationCategory.campaign;
      case 'campaign_booking_confirmed':
      case 'booking_confirmed':
        return CampaignNotificationCategory.booking;
      case 'campaign_reminder':
      case 'vaccine_reminder':
      case 'vaccination_reminder':
      case 'second_dose_reminder':
        return CampaignNotificationCategory.reminder;
      default:
        return CampaignNotificationCategory.campaign;
    }
  }
}
