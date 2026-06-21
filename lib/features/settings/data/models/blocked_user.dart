class BlockedUser {
  final int userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime blockedAt;

  const BlockedUser({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.blockedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'blockedAt': blockedAt.toIso8601String(),
      };

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse('${json['userId']}') ?? 0,
      displayName: json['displayName']?.toString() ?? 'User',
      avatarUrl: json['avatarUrl']?.toString(),
      blockedAt: DateTime.tryParse(json['blockedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
