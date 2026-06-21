/// Firebase Analytics event names and parameter keys (Furtail catalog).
///
/// Event names: ≤40 chars, alphanumeric + underscore, start with letter.
/// See [docs/mobile/analytics_events.md].
abstract final class AnalyticsEvents {
  // --- Event names ---
  static const String login = 'login';
  static const String registration = 'sign_up';
  static const String petCreated = 'pet_created';
  static const String campaignRegistered = 'campaign_registered';
  static const String donationMade = 'donation_made';
  static const String postCreated = 'post_created';
  static const String commentCreated = 'comment_created';
  static const String profileViewed = 'profile_viewed';
  static const String qrViewed = 'qr_viewed';
  static const String certificateViewed = 'certificate_viewed';

  // Campaign funnel (2026 mobile)
  static const String campaignBannerImpression = 'campaign_banner_impression';
  static const String campaignBannerClick = 'campaign_banner_click';
  static const String campaignBookingStarted = 'campaign_booking_started';
  static const String campaignBookingCompleted = 'campaign_booking_completed';
  static const String campaignPaymentStarted = 'campaign_payment_started';
  static const String campaignPaymentCompleted = 'campaign_payment_completed';
  static const String campaignPaymentFailed = 'campaign_payment_failed';
  static const String abTestKey = 'ab_test_key';
  static const String abVariant = 'ab_variant';

  // --- Parameter keys ---
  static const String method = 'method';
  static const String petId = 'pet_id';
  static const String campaignId = 'campaign_id';
  static const String postId = 'post_id';
  static const String commentId = 'comment_id';
  static const String profileUserId = 'profile_user_id';
  static const String amount = 'amount';
  static const String currency = 'currency';
  static const String postType = 'post_type';
  static const String isReply = 'is_reply';
  static const String importedCount = 'imported_count';
  static const String source = 'source';
  static const String hasToken = 'has_token';
}

/// Login / auth methods for [AnalyticsEvents.method].
abstract final class AnalyticsAuthMethod {
  static const String email = 'email';
  static const String google = 'google';
  static const String facebook = 'facebook';
}
