/// Privacy-related preferences (persisted locally).
class PrivacySettings {
  final bool profileVisibleToEveryone;
  final bool showOnlineStatus;
  final bool allowMessagesFromFollowersOnly;
  final bool showActivityInFeed;
  final bool allowTagging;

  const PrivacySettings({
    this.profileVisibleToEveryone = true,
    this.showOnlineStatus = true,
    this.allowMessagesFromFollowersOnly = false,
    this.showActivityInFeed = true,
    this.allowTagging = true,
  });

  PrivacySettings copyWith({
    bool? profileVisibleToEveryone,
    bool? showOnlineStatus,
    bool? allowMessagesFromFollowersOnly,
    bool? showActivityInFeed,
    bool? allowTagging,
  }) {
    return PrivacySettings(
      profileVisibleToEveryone:
          profileVisibleToEveryone ?? this.profileVisibleToEveryone,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowMessagesFromFollowersOnly:
          allowMessagesFromFollowersOnly ?? this.allowMessagesFromFollowersOnly,
      showActivityInFeed: showActivityInFeed ?? this.showActivityInFeed,
      allowTagging: allowTagging ?? this.allowTagging,
    );
  }

  Map<String, dynamic> toJson() => {
        'profileVisibleToEveryone': profileVisibleToEveryone,
        'showOnlineStatus': showOnlineStatus,
        'allowMessagesFromFollowersOnly': allowMessagesFromFollowersOnly,
        'showActivityInFeed': showActivityInFeed,
        'allowTagging': allowTagging,
      };

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    bool b(String key, {bool fallback = true}) => json[key] == false ? false : fallback;
    return PrivacySettings(
      profileVisibleToEveryone: b('profileVisibleToEveryone'),
      showOnlineStatus: b('showOnlineStatus'),
      allowMessagesFromFollowersOnly: json['allowMessagesFromFollowersOnly'] == true,
      showActivityInFeed: b('showActivityInFeed'),
      allowTagging: b('allowTagging'),
    );
  }
}
