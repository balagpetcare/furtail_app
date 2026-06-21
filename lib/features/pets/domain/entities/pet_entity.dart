import 'dart:io';

class PetEntity {
  final int? id;
  final String name;

  final int animalTypeId;
  final int? breedId;
  final int? profilePicId;

  // ✅ NEW: local image file (for upload)
  final File? photo; // 🔥 ADD THIS

  // UI display fields
  final String? animalTypeName;
  final String? breedName;

  final DateTime? dateOfBirth;
  final String? sex;
  final String? microchipNumber;
  final bool? isRescue;
  final bool? isNeutered;
  final String? foodHabits;
  final String? healthDisorders;
  final String? notes;
  final double? weightKg;
  final String? photoUrl;

  const PetEntity({
    this.id,
    required this.name,
    required this.animalTypeId,
    this.breedId,
    this.animalTypeName,
    this.breedName,
    this.dateOfBirth,
    this.sex,
    this.microchipNumber,
    this.isRescue,
    this.isNeutered,
    this.foodHabits,
    this.healthDisorders,
    this.notes,
    this.weightKg,
    this.photoUrl,
    this.profilePicId,

    this.photo, // 🔥 ADD THIS
  });

  String get animalType => animalTypeName ?? "";
  String get breed => breedName ?? "";
}
