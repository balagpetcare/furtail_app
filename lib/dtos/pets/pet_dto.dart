class PetDto {
  final int id;
  final String name;
  final int? age;
  final String? profilePicUrl;

  PetDto({required this.id, required this.name, this.age, this.profilePicUrl});

  factory PetDto.fromJson(Map<String, dynamic> json) {
    // backend response structure ভিন্ন হলে এখানে adjust করবেন
    return PetDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      age: json['age'] == null ? null : (json['age'] as num).toInt(),
      profilePicUrl:
          json['profilePic']?['url']?.toString() ??
          json['profilePicUrl']?.toString(),
    );
  }
}
