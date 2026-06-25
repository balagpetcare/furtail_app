class PostCommentAuthorModel {
  final int id;
  final String name;
  final String? avatarUrl;

  PostCommentAuthorModel({required this.id, required this.name, this.avatarUrl});

  factory PostCommentAuthorModel.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? {};
    final avatarMedia = (profile['avatarMedia'] as Map<String, dynamic>?) ?? {};
    final displayName = (profile['displayName'] ?? profile['username'] ?? 'User').toString();
    final avatarUrl = (avatarMedia['url'] as String?)?.trim();
    return PostCommentAuthorModel(
      id: (json['id'] as num).toInt(),
      name: displayName,
      avatarUrl: avatarUrl?.isEmpty == true ? null : avatarUrl,
    );
  }
}

class PostCommentModel {
  final int id;
  final String text;
  final DateTime createdAt;
  final PostCommentAuthorModel author;
  final int likeCount;
  final bool isLikedByMe;
  final int? parentId;

  // ── Phase 1: Premium comment fields ─────────────────────────────────────
  /// Whether the comment has been edited after creation.
  final bool isEdited;
  /// Optional media attachment URL (image/video) attached to the comment.
  final String? attachmentUrl;
  /// Number of replies to this comment (useful for paginated replies).
  final int replyCount;

  PostCommentModel({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.author,
    this.likeCount = 0,
    this.isLikedByMe = false,
    this.parentId,
    this.isEdited = false,
    this.attachmentUrl,
    this.replyCount = 0,
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    return PostCommentModel(
      id: (json['id'] as num).toInt(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      author: PostCommentAuthorModel.fromJson((json['user'] as Map<String, dynamic>?) ?? const {'id': 0}),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: (json['isLikedByMe'] as bool?) ?? false,
      parentId: (json['parentId'] as num?)?.toInt(),
      isEdited: (json['isEdited'] as bool?) ?? false,
      attachmentUrl: (json['attachmentUrl'] as String?)?.trim(),
      replyCount: ((json['replyCount'] as num?) ?? 0).toInt(),
    );
  }

  PostCommentModel copyWith({
    int? id,
    String? text,
    DateTime? createdAt,
    PostCommentAuthorModel? author,
    int? likeCount,
    bool? isLikedByMe,
    int? parentId,
    bool? isEdited,
    String? attachmentUrl,
    int? replyCount,
  }) {
    return PostCommentModel(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      parentId: parentId ?? this.parentId,
      isEdited: isEdited ?? this.isEdited,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      replyCount: replyCount ?? this.replyCount,
    );
  }
}
