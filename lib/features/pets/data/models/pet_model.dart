import '../../domain/entities/pet_entity.dart';
import 'package:flutter/foundation.dart';

class PetModel extends PetEntity {
  const PetModel({
    super.id,
    required super.name,
    required super.animalTypeId,
    super.breedId,
    super.subBreedId,
    super.colorId,
    super.coatPatternId,
    super.sizeId,
    super.customBreedText,
    super.customColorText,
    super.animalTypeName,
    super.breedName,
    super.colorName,
    super.sizeName,
    super.coatPatternName,
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
    super.bloodType,
    super.allergies,
    super.slug,
    super.bio,
    super.coverMediaId,
    super.coverMediaUrl,
    super.isPublicProfileEnabled,
    super.visibility,
    super.followersCount,
    super.likesCount,
    super.isFollowing,
    super.isLiked,
    super.isOwner,
    super.canManage,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) {
    debugPrint("PET JSON: $json");

    final animalType = json["animalType"];
    final breed = json["breed"];

    final animalTypeName = (animalType is Map)
        ? animalType["name"]?.toString()
        : (json["animalTypeNameSnapshot"] ?? animalType?.toString());

    final breedName = (breed is Map)
        ? breed["name"]?.toString()
        : (json["breedNameSnapshot"] ?? breed?.toString());

    final profilePic = json["profilePic"];
    final photoUrl = (profilePic is Map)
        ? profilePic["url"]?.toString()
        : json["photoUrl"]?.toString();

    final coverMedia = json["coverMedia"];
    final coverMediaUrl = (coverMedia is Map) ? coverMedia["url"]?.toString() : null;

    // Resolve latest weight from nested weights array
    double? weightKg;
    final weights = json["weights"];
    if (weights is List && weights.isNotEmpty) {
      weightKg = double.tryParse(weights.first["weightKg"]?.toString() ?? "");
    } else if (json["weightKg"] != null) {
      weightKg = double.tryParse(json["weightKg"].toString());
    }

    List<String>? allergies;
    final rawAllergies = json["allergies"];
    if (rawAllergies is List) {
      allergies = rawAllergies.map((e) => e.toString()).toList();
    }

    return PetModel(
      id: json["id"] as int?,
      name: (json["name"] ?? "").toString(),
      animalTypeId: (json["animalTypeId"] as num).toInt(),
      breedId: json["breedId"] != null ? (json["breedId"] as num).toInt() : null,
      subBreedId: json["subBreedId"] != null ? (json["subBreedId"] as num).toInt() : null,
      colorId: json["colorId"] != null ? (json["colorId"] as num).toInt() : null,
      coatPatternId: json["coatPatternId"] != null ? (json["coatPatternId"] as num).toInt() : null,
      sizeId: json["sizeId"] != null ? (json["sizeId"] as num).toInt() : null,
      customBreedText: json["customBreedText"]?.toString(),
      customColorText: json["customColorText"]?.toString(),
      profilePicId: json["profilePicId"] != null ? (json["profilePicId"] as num).toInt() : null,
      animalTypeName: animalTypeName,
      breedName: breedName,
      colorName: (json["colorNameSnapshot"] ?? json["customColorText"])?.toString(),
      sizeName: json["sizeNameSnapshot"]?.toString(),
      coatPatternName: json["coatPatternNameSnapshot"]?.toString(),
      dateOfBirth: json["dateOfBirth"] == null
          ? null
          : DateTime.tryParse(json["dateOfBirth"].toString()),
      sex: (json["sex"] ?? "UNKNOWN").toString(),
      microchipNumber: json["microchipNumber"]?.toString(),
      isRescue: json["isRescue"] == true,
      isNeutered: json["isNeutered"] == true,
      foodHabits: json["foodHabits"]?.toString(),
      healthDisorders: json["healthDisorders"]?.toString(),
      notes: json["notes"]?.toString(),
      weightKg: weightKg,
      photoUrl: photoUrl,
      bloodType: json["bloodType"]?.toString(),
      allergies: allergies,
      slug: json["slug"]?.toString(),
      bio: json["bio"]?.toString(),
      coverMediaId: json["coverMediaId"] != null ? (json["coverMediaId"] as num).toInt() : null,
      coverMediaUrl: coverMediaUrl,
      isPublicProfileEnabled: json["isPublicProfileEnabled"] == true,
      visibility: json["visibility"]?.toString() ?? "PRIVATE",
      followersCount: json["followersCount"] != null ? (json["followersCount"] as num).toInt() : 0,
      likesCount: json["likesCount"] != null ? (json["likesCount"] as num).toInt() : 0,
      isFollowing: json["isFollowing"] as bool?,
      isLiked: json["isLiked"] as bool?,
      isOwner: json["isOwner"] as bool?,
      canManage: json["canManage"] as bool?,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      "name": name,
      "animalTypeId": animalTypeId,
      if (breedId != null) "breedId": breedId,
      if (subBreedId != null) "subBreedId": subBreedId,
      if (colorId != null) "colorId": colorId,
      if (coatPatternId != null) "coatPatternId": coatPatternId,
      if (sizeId != null) "sizeId": sizeId,
      if (customBreedText != null && customBreedText!.isNotEmpty)
        "customBreedText": customBreedText,
      if (customColorText != null && customColorText!.isNotEmpty)
        "customColorText": customColorText,
      if (profilePicId != null) "profilePicId": profilePicId,
      "dateOfBirth": dateOfBirth?.toIso8601String(),
      "sex": sex,
      "microchipNumber":
          (microchipNumber ?? "").trim().isEmpty ? null : microchipNumber!.trim(),
      "isRescue": isRescue ?? false,
      "isNeutered": isNeutered ?? false,
      "foodHabits":
          (foodHabits ?? "").trim().isEmpty ? null : foodHabits!.trim(),
      "healthDisorders":
          (healthDisorders ?? "").trim().isEmpty ? null : healthDisorders!.trim(),
      "notes": (notes ?? "").trim().isEmpty ? null : notes!.trim(),
      if (weightKg != null) "weightKg": weightKg,
      if (bloodType != null && bloodType!.isNotEmpty) "bloodType": bloodType,
      if (allergies != null) "allergies": allergies,
    };
  }
}
