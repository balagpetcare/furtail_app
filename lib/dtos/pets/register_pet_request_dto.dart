class RegisterPetRequestDto {
  final String name;
  final int animalTypeId;
  final int? breedId;

  final String sex; // "MALE" | "FEMALE" | "UNKNOWN"
  final String? dateOfBirth; // "YYYY-MM-DD"
  final double? weightKg;

  final String? microchipNumber;
  final bool isRescue;
  final bool isNeutered;

  final String? foodHabits;
  final String? healthDisorders;
  final String? notes;

  final int? lastVaccineId;
  final String? lastVaccineDate; // "YYYY-MM-DD"

  RegisterPetRequestDto({
    required this.name,
    required this.animalTypeId,
    required this.breedId,
    required this.sex,
    required this.dateOfBirth,
    required this.weightKg,
    required this.microchipNumber,
    required this.isRescue,
    required this.isNeutered,
    required this.foodHabits,
    required this.healthDisorders,
    required this.notes,
    required this.lastVaccineId,
    required this.lastVaccineDate,
  });

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "animalTypeId": animalTypeId,
      "breedId": breedId, // null allowed
      "sex": sex,
      "dateOfBirth": dateOfBirth,
      "weightKg": weightKg,
      "microchipNumber": microchipNumber,
      "isRescue": isRescue,
      "isNeutered": isNeutered,
      "foodHabits": foodHabits,
      "healthDisorders": healthDisorders,
      "notes": notes,
      "lastVaccineId": lastVaccineId,
      "lastVaccineDate": lastVaccineDate,
    };
  }
}
