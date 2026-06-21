class BreedDto {
  final int id;
  final String name;

  BreedDto({required this.id, required this.name});

  factory BreedDto.fromJson(Map<String, dynamic> json) {
    return BreedDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
    );
  }
}
