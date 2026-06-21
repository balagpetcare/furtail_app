class AnimalTypeDto {
  final int id;
  final String name;

  AnimalTypeDto({required this.id, required this.name});

  factory AnimalTypeDto.fromJson(Map<String, dynamic> json) {
    return AnimalTypeDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
    );
  }
}
