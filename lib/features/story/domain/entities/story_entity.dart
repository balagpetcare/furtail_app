class StoryEntity {
  final int id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? mediaUrl;
  final String? mediaType;
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
    this.mediaType,
    this.caption,
    required this.createdAt,
    this.isViewedByMe = false,
    this.isOwnStory = false,
    this.viewCount = 0,
  });
}
