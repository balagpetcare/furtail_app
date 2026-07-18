import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    super.avatarUrl,
  });

  /// Parses the Furtail API's `GET /api/v1/auth/me` response (`res.json({
  /// success, user, ... })`), where `user` is the local Prisma `User`
  /// record — the local Furtail identity that a Central Auth user gets
  /// resolved/JIT-provisioned to. Defensive about field names since the
  /// backend nests display fields under `profile` and contact fields can
  /// live on `user` or `user.auth`.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : const <String, dynamic>{};
    final auth = json['auth'] is Map
        ? Map<String, dynamic>.from(json['auth'] as Map)
        : const <String, dynamic>{};

    String? avatarUrl;
    final avatarMedia = profile['avatarMedia'];
    if (avatarMedia is Map) {
      avatarUrl = avatarMedia['url']?.toString();
    }
    avatarUrl ??= profile['avatarUrl']?.toString();

    final rawId = json['id'];
    if (rawId == null) {
      throw const FormatException(
        "Missing required 'id' field in user profile",
      );
    }
    final int parsedId = rawId is int
        ? rawId
        : int.tryParse(rawId.toString()) ??
              (throw const FormatException(
                "Invalid 'id' format in user profile",
              ));

    return UserModel(
      id: parsedId,
      name:
          (json['name'] ??
                  json['displayName'] ??
                  profile['fullName'] ??
                  json['username'] ??
                  json['email'] ??
                  json['phone'] ??
                  '')
              .toString(),
      email: (json['email'] ?? auth['email'] ?? '').toString(),
      phone: (json['phone'] ?? auth['phone'] ?? auth['mobile'])?.toString(),
      avatarUrl: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          ? avatarUrl.trim()
          : null,
    );
  }
}
