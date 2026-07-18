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
  // Social notifications
  friendRequestReceived('friend_request_received'),
  friendRequestAccepted('friend_request_accepted'),
  userFollowed('user_followed'),
  petFollowed('pet_followed'),
  petLiked('pet_liked'),
  adoptionLike('adoption_like'),
  adoptionComment('adoption_comment'),
  adoptionApplicationSubmitted('adoption_application_submitted'),
  adoptionApplicationApproved('adoption_application_approved'),
  adoptionApplicationRejected('adoption_application_rejected'),
  adoptionListingStatusChanged('adoption_listing_status_changed'),

  /// Generic push when server omits a known type.
  general('general');

  const AppNotificationType(this.code);

  final String code;

  bool get isSocial =>
      this == friendRequestReceived ||
      this == friendRequestAccepted ||
      this == userFollowed ||
      this == petFollowed ||
      this == petLiked;

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
      // Social types — backend sends UPPER_SNAKE_CASE
      case 'friend_request_received':
        return AppNotificationType.friendRequestReceived;
      case 'friend_request_accepted':
        return AppNotificationType.friendRequestAccepted;
      case 'user_followed':
        return AppNotificationType.userFollowed;
      case 'pet_followed':
        return AppNotificationType.petFollowed;
      case 'pet_liked':
        return AppNotificationType.petLiked;
      case 'adoption_like':
        return AppNotificationType.adoptionLike;
      case 'adoption_comment':
        return AppNotificationType.adoptionComment;
      case 'adoption_application_submitted':
        return AppNotificationType.adoptionApplicationSubmitted;
      case 'adoption_application_approved':
        return AppNotificationType.adoptionApplicationApproved;
      case 'adoption_application_rejected':
        return AppNotificationType.adoptionApplicationRejected;
      case 'adoption_listing_status_changed':
        return AppNotificationType.adoptionListingStatusChanged;
      default:
        return AppNotificationType.general;
    }
  }
}
