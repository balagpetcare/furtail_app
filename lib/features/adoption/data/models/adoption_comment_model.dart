class AdoptionCommentAuthorModel {
  final int id;
  final String name;
  final String? avatarUrl;

  const AdoptionCommentAuthorModel({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory AdoptionCommentAuthorModel.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? const {};
    final avatarMedia =
        (profile['avatarMedia'] as Map<String, dynamic>?) ?? const {};
    final displayName =
        (profile['displayName'] ?? profile['username'] ?? 'User').toString();
    final avatarUrl = (avatarMedia['url'] as String?)?.trim();
    return AdoptionCommentAuthorModel(
      id: (json['id'] as num).toInt(),
      name: displayName,
      avatarUrl: avatarUrl?.isEmpty == true ? null : avatarUrl,
    );
  }
}

class AdoptionCommentModel {
  final int id;
  final String text;
  final DateTime createdAt;
  final AdoptionCommentAuthorModel author;
  final bool canDelete;

  const AdoptionCommentModel({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.author,
    this.canDelete = false,
  });

  factory AdoptionCommentModel.fromJson(Map<String, dynamic> json) {
    return AdoptionCommentModel(
      id: (json['id'] as num).toInt(),
      text: (json['text'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      author: AdoptionCommentAuthorModel.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {'id': 0},
      ),
      canDelete: (json['canDelete'] as bool?) ?? false,
    );
  }
}
