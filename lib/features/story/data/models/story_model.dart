import 'package:furtail_app/core/media/media_url.dart';

/// Story data model — maps JSON from /api/v1/stories/ endpoints.
///
/// `mediaUrl`/`thumbnailUrl`/`userAvatarUrl` are normalized via
/// [MediaUrl.normalize] at parse time (same as every other media surface in
/// the app — posts, pets, profile, fundraising, adoption) so a relative path
/// or a localhost/docker-internal host the backend may return becomes a real,
/// device-reachable URL before it ever reaches a display widget.
class StoryModel {
  final int id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? mediaUrl; // image or video
  final String? thumbnailUrl; // poster/cover — same as mediaUrl for images
  final String? mediaType; // "image" | "video"
  final int? width;
  final int? height;
  final int?
  durationMs; // video only; null for images or while still processing
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
    this.thumbnailUrl,
    this.mediaType,
    this.width,
    this.height,
    this.durationMs,
    this.caption,
    required this.createdAt,
    this.expiresAt,
    this.viewCount = 0,
    this.isViewedByMe = false,
    this.isOwnStory = false,
  });

  static String? _normalizedOrNull(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.trim().isEmpty) return null;
    return MediaUrl.normalize(value);
  }

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final mediaUrl = _normalizedOrNull(
      json['mediaUrl'] ?? json['media_url'] ?? json['imageUrl'],
    );
    return StoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      userName: (json['userName'] ?? json['user_name'] ?? '').toString(),
      userAvatarUrl: _normalizedOrNull(
        json['userAvatarUrl'] ?? json['user_avatar_url'],
      ),
      mediaUrl: mediaUrl,
      // Falls back to mediaUrl (e.g. an image, or a video whose poster
      // frame hasn't finished processing yet) rather than showing nothing.
      thumbnailUrl:
          _normalizedOrNull(json['thumbnailUrl'] ?? json['thumbnail_url']) ??
          mediaUrl,
      mediaType: (json['mediaType'] ?? json['media_type'] ?? 'image')
          .toString(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationMs: ((json['durationMs'] ?? json['duration_ms']) as num?)
          ?.toInt(),
      caption: json['caption']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      viewCount: (json['viewCount'] ?? json['view_count'] ?? 0) as int,
      isViewedByMe:
          (json['isViewedByMe'] ?? json['is_viewed_by_me'] ?? false) as bool,
      isOwnStory: (json['isOwnStory'] ?? json['is_own_story'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'userAvatarUrl': userAvatarUrl,
    'mediaUrl': mediaUrl,
    'thumbnailUrl': thumbnailUrl,
    'mediaType': mediaType,
    'width': width,
    'height': height,
    'durationMs': durationMs,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'viewCount': viewCount,
    'isViewedByMe': isViewedByMe,
    'isOwnStory': isOwnStory,
  };
}
