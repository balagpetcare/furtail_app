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

  PostCommentModel({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.author,
    this.likeCount = 0,
    this.isLikedByMe = false,
    this.parentId,
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
  }) {
    return PostCommentModel(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      parentId: parentId ?? this.parentId,
    );
  }
}
