class CreatePetRequestDto {
  final String name;
  final int age;
  final String? description;
  final int animalTypeId;
  final int breedId;

  CreatePetRequestDto({
    required this.name,
    required this.age,
    this.description,
    required this.animalTypeId,
    required this.breedId,
  });

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "age": age,
      "description": description,
      "animalTypeId": animalTypeId,
      "breedId": breedId,
    };
  }
}
