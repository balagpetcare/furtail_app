/// Story data model — maps JSON from /api/v1/stories/ endpoints.
class StoryModel {
  final int id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? mediaUrl; // image or video
  final String? mediaType; // "image" | "video"
  final String? caption;
  final DateTime createdAt;
  final DateTime? expiresAt; // null → 24h from createdAt
  final int viewCount;
  final bool isViewedByMe;
  final bool isOwnStory;

  const StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.mediaUrl,
    this.mediaType,
    this.caption,
    required this.createdAt,
    this.expiresAt,
    this.viewCount = 0,
    this.isViewedByMe = false,
    this.isOwnStory = false,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      userName: (json['userName'] ?? json['user_name'] ?? '').toString(),
      userAvatarUrl: (json['userAvatarUrl'] ?? json['user_avatar_url'])?.toString(),
      mediaUrl: (json['mediaUrl'] ?? json['media_url'] ?? json['imageUrl'])?.toString(),
      mediaType: (json['mediaType'] ?? json['media_type'] ?? 'image').toString(),
      caption: json['caption']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      viewCount: (json['viewCount'] ?? json['view_count'] ?? 0) as int,
      isViewedByMe: (json['isViewedByMe'] ?? json['is_viewed_by_me'] ?? false) as bool,
      isOwnStory: (json['isOwnStory'] ?? json['is_own_story'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'userAvatarUrl': userAvatarUrl,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'viewCount': viewCount,
    'isViewedByMe': isViewedByMe,
    'isOwnStory': isOwnStory,
  };
}