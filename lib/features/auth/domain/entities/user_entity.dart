class UserEntity {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
  });
}
