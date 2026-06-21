/// Local (+ optional server) notification channel preferences.
class NotificationPreferences {
  final bool pushEnabled;
  final bool campaignReminders;
  final bool vaccineReminders;
  final bool donationUpdates;
  final bool communityActivity;
  final bool comments;
  final bool likes;
  final bool follows;
  final bool announcements;
  final bool emergency;
  final bool allowEmail;
  final bool allowSms;

  const NotificationPreferences({
    this.pushEnabled = true,
    this.campaignReminders = true,
    this.vaccineReminders = true,
    this.donationUpdates = true,
    this.communityActivity = true,
    this.comments = true,
    this.likes = true,
    this.follows = true,
    this.announcements = true,
    this.emergency = true,
    this.allowEmail = true,
    this.allowSms = false,
  });

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? campaignReminders,
    bool? vaccineReminders,
    bool? donationUpdates,
    bool? communityActivity,
    bool? comments,
    bool? likes,
    bool? follows,
    bool? announcements,
    bool? emergency,
    bool? allowEmail,
    bool? allowSms,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      campaignReminders: campaignReminders ?? this.campaignReminders,
      vaccineReminders: vaccineReminders ?? this.vaccineReminders,
      donationUpdates: donationUpdates ?? this.donationUpdates,
      communityActivity: communityActivity ?? this.communityActivity,
      comments: comments ?? this.comments,
      likes: likes ?? this.likes,
      follows: follows ?? this.follows,
      announcements: announcements ?? this.announcements,
      emergency: emergency ?? this.emergency,
      allowEmail: allowEmail ?? this.allowEmail,
      allowSms: allowSms ?? this.allowSms,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'campaignReminders': campaignReminders,
        'vaccineReminders': vaccineReminders,
        'donationUpdates': donationUpdates,
        'communityActivity': communityActivity,
        'comments': comments,
        'likes': likes,
        'follows': follows,
        'announcements': announcements,
        'emergency': emergency,
        'allowEmail': allowEmail,
        'allowSms': allowSms,
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    bool b(String key, {bool fallback = true}) => json[key] == false ? false : fallback;
    return NotificationPreferences(
      pushEnabled: b('pushEnabled'),
      campaignReminders: b('campaignReminders'),
      vaccineReminders: b('vaccineReminders'),
      donationUpdates: b('donationUpdates'),
      communityActivity: b('communityActivity'),
      comments: b('comments'),
      likes: b('likes'),
      follows: b('follows'),
      announcements: b('announcements'),
      emergency: b('emergency', fallback: true),
      allowEmail: b('allowEmail'),
      allowSms: json['allowSms'] == true,
    );
  }

  /// Merge server notification settings when available.
  factory NotificationPreferences.fromServer(Map<String, dynamic>? server) {
    if (server == null || server.isEmpty) return const NotificationPreferences();
    return NotificationPreferences(
      allowEmail: server['allowEmail'] != false,
      allowSms: server['allowSms'] == true,
    );
  }
}
