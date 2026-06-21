/// Live countdown snapshot for a campaign banner.
class CampaignCountdownSnapshot {
  final String slug;
  final String campaignName;
  final DateTime? targetAt;
  final bool countdownEnabled;
  final bool isBookingWindow;

  const CampaignCountdownSnapshot({
    required this.slug,
    required this.campaignName,
    this.targetAt,
    this.countdownEnabled = false,
    this.isBookingWindow = true,
  });

  Duration? get remaining {
    if (targetAt == null) return null;
    final diff = targetAt!.difference(DateTime.now());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  int get daysLeft => remaining?.inDays ?? 0;
  int get hoursLeft => remaining == null ? 0 : (remaining!.inHours % 24);

  bool get isExpired => remaining != null && remaining!.inSeconds <= 0;

  factory CampaignCountdownSnapshot.fromJson(String slug, Map<String, dynamic> json) {
    final bookingEnd = json['bookingEndAt'];
    final bookingStart = json['bookingStartAt'];
    DateTime? target;
    if (bookingEnd != null) {
      target = DateTime.tryParse(bookingEnd.toString());
    }
    return CampaignCountdownSnapshot(
      slug: slug,
      campaignName: json['campaignName']?.toString() ?? '',
      targetAt: target,
      countdownEnabled: json['countdownEnabled'] == true,
      isBookingWindow: bookingStart == null ||
          DateTime.now().isAfter(DateTime.tryParse(bookingStart.toString()) ?? DateTime.now()),
    );
  }
}
