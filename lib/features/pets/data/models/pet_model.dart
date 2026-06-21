import '../../domain/entities/pet_entity.dart';
import 'package:flutter/foundation.dart';

class PetModel extends PetEntity {
  const PetModel({
    super.id,
    required super.name,
    required super.animalTypeId,
    super.breedId,

    super.animalTypeName,
    super.breedName,

    super.dateOfBirth,
    super.sex,
    super.microchipNumber,
    super.isRescue,
    super.isNeutered,
    super.foodHabits,
    super.healthDisorders,
    super.notes,
    super.weightKg,
    super.photoUrl,
    super.profilePicId,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) {
    debugPrint("PET JSON: $json");
    debugPrint("PET PROFILE PIC URL: ${json["profilePic"]?["url"]}");

    final animalType = json["animalType"];
    final breed = json["breed"];

    final animalTypeName = (animalType is Map)
        ? animalType["name"]?.toString()
        : animalType?.toString();

    final breedName = (breed is Map)
        ? breed["name"]?.toString()
        : breed?.toString();

    // profilePic can be {url:"..."} or photoUrl can be "...":
    final profilePic = json["profilePic"];
    final photoUrl = (profilePic is Map)
        ? profilePic["url"]?.toString()
        : json["photoUrl"]?.toString();

    return PetModel(
      id: json["id"] as int?, // ✅ nullable safe
      name: (json["name"] ?? "").toString(),
      animalTypeId: json["animalTypeId"] as int,
      breedId: json["breedId"] as int?, // ✅ nullable safe
      profilePicId: json["profilePicId"],
      animalTypeName: animalTypeName,
      breedName: breedName,

      dateOfBirth: json["dateOfBirth"] == null
          ? null
          : DateTime.tryParse(json["dateOfBirth"].toString()),
      sex: (json["sex"] ?? "UNKNOWN").toString(),
      microchipNumber: json["microchipNumber"]?.toString(),
      isRescue: (json["isRescue"] ?? false) == true,
      isNeutered: (json["isNeutered"] ?? false) == true,
      foodHabits: json["foodHabits"]?.toString(),
      healthDisorders: json["healthDisorders"]?.toString(),
      notes: json["notes"]?.toString(),
      weightKg: json["weightKg"] == null
          ? null
          : double.tryParse(json["weightKg"].toString()),
      photoUrl: photoUrl,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      "name": name,
      "animalTypeId": animalTypeId,
      "breedId": breedId, // ✅ nullable OK
      if (profilePicId != null) "profilePicId": profilePicId,
      "dateOfBirth": dateOfBirth?.toIso8601String(),
      "sex": sex,

      "microchipNumber": (microchipNumber ?? "").trim().isEmpty
          ? null
          : (microchipNumber ?? "").trim(),

      "isRescue": isRescue ?? false,
      "isNeutered": isNeutered ?? false,

      "foodHabits": (foodHabits ?? "").trim().isEmpty
          ? null
          : (foodHabits ?? "").trim(),
      "healthDisorders": (healthDisorders ?? "").trim().isEmpty
          ? null
          : (healthDisorders ?? "").trim(),
      "notes": (notes ?? "").trim().isEmpty ? null : (notes ?? "").trim(),

      "weightKg": weightKg,
    };
  }
}
