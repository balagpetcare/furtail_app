class StoryEntity {
  final int id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? mediaType;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? caption;
  final DateTime createdAt;
  final bool isViewedByMe;
  final bool isOwnStory;
  final int viewCount;

  const StoryEntity({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaType,
    this.width,
    this.height,
    this.durationMs,
    this.caption,
    required this.createdAt,
    this.isViewedByMe = false,
    this.isOwnStory = false,
    this.viewCount = 0,
  });

  StoryEntity copyWith({bool? isViewedByMe, int? viewCount}) {
    return StoryEntity(
      id: id,
      userId: userId,
      userName: userName,
      userAvatarUrl: userAvatarUrl,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      mediaType: mediaType,
      width: width,
      height: height,
      durationMs: durationMs,
      caption: caption,
      createdAt: createdAt,
      isViewedByMe: isViewedByMe ?? this.isViewedByMe,
      isOwnStory: isOwnStory,
      viewCount: viewCount ?? this.viewCount,
    );
  }
}
