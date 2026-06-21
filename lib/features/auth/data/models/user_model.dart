import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? 0) is int
          ? json['id']
          : int.tryParse('${json['id']}') ?? 0,
      // Backend may return displayName/username instead of name.
      name: (json['name'] ?? json['displayName'] ?? json['username'] ?? '')
          .toString(),
      email: (json['email'] ?? '').toString(),
    );
  }
}
