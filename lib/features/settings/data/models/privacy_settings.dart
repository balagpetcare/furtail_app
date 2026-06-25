enum CommentPermission { everyone, followersOnly, noOne }

/// Privacy-related preferences (persisted locally).
class PrivacySettings {
  final bool profileVisibleToEveryone;
  final bool showOnlineStatus;
  final bool allowMessagesFromFollowersOnly;
  final bool showActivityInFeed;
  final bool allowTagging;
  final CommentPermission whoCanComment;

  const PrivacySettings({
    this.profileVisibleToEveryone = true,
    this.showOnlineStatus = true,
    this.allowMessagesFromFollowersOnly = false,
    this.showActivityInFeed = true,
    this.allowTagging = true,
    this.whoCanComment = CommentPermission.everyone,
  });

  PrivacySettings copyWith({
    bool? profileVisibleToEveryone,
    bool? showOnlineStatus,
    bool? allowMessagesFromFollowersOnly,
    bool? showActivityInFeed,
    bool? allowTagging,
    CommentPermission? whoCanComment,
  }) {
    return PrivacySettings(
      profileVisibleToEveryone:
          profileVisibleToEveryone ?? this.profileVisibleToEveryone,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowMessagesFromFollowersOnly:
          allowMessagesFromFollowersOnly ?? this.allowMessagesFromFollowersOnly,
      showActivityInFeed: showActivityInFeed ?? this.showActivityInFeed,
      allowTagging: allowTagging ?? this.allowTagging,
      whoCanComment: whoCanComment ?? this.whoCanComment,
    );
  }

  Map<String, dynamic> toJson() => {
        'profileVisibleToEveryone': profileVisibleToEveryone,
        'showOnlineStatus': showOnlineStatus,
        'allowMessagesFromFollowersOnly': allowMessagesFromFollowersOnly,
        'showActivityInFeed': showActivityInFeed,
        'allowTagging': allowTagging,
        'whoCanComment': whoCanComment.name,
      };

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    bool b(String key, {bool fallback = true}) => json[key] == false ? false : fallback;
    return PrivacySettings(
      profileVisibleToEveryone: b('profileVisibleToEveryone'),
      showOnlineStatus: b('showOnlineStatus'),
      allowMessagesFromFollowersOnly: json['allowMessagesFromFollowersOnly'] == true,
      showActivityInFeed: b('showActivityInFeed'),
      allowTagging: b('allowTagging'),
      whoCanComment: CommentPermission.values.firstWhere(
        (e) => e.name == json['whoCanComment'],
        orElse: () => CommentPermission.everyone,
      ),
    );
  }
}
