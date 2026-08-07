import '../../domain/entities/pet_entity.dart';
import 'package:furtail_app/core/media/media_url.dart';

class PetModel extends PetEntity {
  const PetModel({
    super.id,
    required super.name,
    super.version,
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
    super.clearProfileImage,
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
    this.canViewFullProfile = true,
  });

  final bool canViewFullProfile;

  factory PetModel.fromJson(Map<String, dynamic> json) {
    final animalType = json["animalType"];
    final breed = json["breed"];

    final animalTypeName = (animalType is Map)
        ? animalType["name"]?.toString()
        : (json["animalTypeName"] ??
              json["animalTypeNameSnapshot"] ??
              animalType?.toString());

    final breedName = (breed is Map)
        ? breed["name"]?.toString()
        : (json["breedName"] ?? json["breedNameSnapshot"] ?? breed?.toString());

    final profilePic = json["profilePic"];
    final rawPhotoUrl = (profilePic is Map)
        ? profilePic["url"]?.toString()
        : json["photoUrl"]?.toString();
    final photoUrl = _normalizedUrl(rawPhotoUrl);

    final coverMedia = json["coverMedia"];
    final rawCoverUrl = (coverMedia is Map)
        ? coverMedia["url"]?.toString()
        : null;
    final coverMediaUrl = _normalizedUrl(rawCoverUrl);

    // Resolve latest weight from nested weights array
    double? weightKg;
    final weights = json["weights"];
    if (weights is List && weights.isNotEmpty && weights.first is Map) {
      weightKg = double.tryParse(
        ((weights.first as Map)["weightKg"] ?? '').toString(),
      );
    } else if (json["weightKg"] != null) {
      weightKg = double.tryParse(json["weightKg"].toString());
    }

    List<String>? allergies;
    final rawAllergies = json["allergies"];
    if (rawAllergies is List) {
      allergies = rawAllergies.map((e) => e.toString()).toList();
    }

    return PetModel(
      id: _int(json["id"]),
      name: (json["name"] ?? "").toString(),
      version: _int(json["version"]),
      animalTypeId: _int(json["animalTypeId"]) ?? 0,
      breedId: _int(json["breedId"]),
      subBreedId: _int(json["subBreedId"]),
      colorId: _int(json["colorId"]),
      coatPatternId: _int(json["coatPatternId"]),
      sizeId: _int(json["sizeId"]),
      customBreedText: json["customBreedText"]?.toString(),
      customColorText: json["customColorText"]?.toString(),
      profilePicId: _int(json["profilePicId"] ?? json["profileImageId"]),
      animalTypeName: animalTypeName,
      breedName: breedName,
      colorName:
          (json["colorName"] ??
                  json["colorNameSnapshot"] ??
                  json["customColorText"])
              ?.toString(),
      sizeName: (json["sizeName"] ?? json["sizeNameSnapshot"])?.toString(),
      coatPatternName:
          (json["coatPatternName"] ?? json["coatPatternNameSnapshot"])
              ?.toString(),
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
      coverMediaId: _int(json["coverMediaId"]),
      coverMediaUrl: coverMediaUrl,
      isPublicProfileEnabled: json["isPublicProfileEnabled"] == true,
      visibility: json["visibility"]?.toString() ?? "PRIVATE",
      followersCount: _int(json["followersCount"]) ?? 0,
      likesCount: _int(json["likesCount"]) ?? 0,
      isFollowing: json["isFollowing"] as bool?,
      isLiked: json["isLiked"] as bool?,
      isOwner: json["isOwner"] as bool?,
      canManage: json["canManage"] as bool?,
      canViewFullProfile: json["canViewFullProfile"] as bool? ?? true,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      "name": name,
      "animalTypeId": animalTypeId,
      if (version != null) "version": version,
      if (breedId != null) "breedId": breedId,
      if (subBreedId != null) "subBreedId": subBreedId,
      if (colorId != null) "colorId": colorId,
      if (coatPatternId != null) "coatPatternId": coatPatternId,
      if (sizeId != null) "sizeId": sizeId,
      if (customBreedText != null && customBreedText!.isNotEmpty)
        "customBreedText": customBreedText,
      if (customColorText != null && customColorText!.isNotEmpty)
        "customColorText": customColorText,
      if (profilePicId != null) "profileImageId": profilePicId,
      "dateOfBirth": dateOfBirth?.toIso8601String(),
      "sex": sex,
      "microchipNumber": (microchipNumber ?? "").trim().isEmpty
          ? null
          : microchipNumber!.trim(),
      "isRescue": isRescue ?? false,
      "isNeutered": isNeutered ?? false,
      "foodHabits": (foodHabits ?? "").trim().isEmpty
          ? null
          : foodHabits!.trim(),
      "healthDisorders": (healthDisorders ?? "").trim().isEmpty
          ? null
          : healthDisorders!.trim(),
      "notes": (notes ?? "").trim().isEmpty ? null : notes!.trim(),
      if (weightKg != null) "weightKg": weightKg,
      if (bloodType != null && bloodType!.isNotEmpty) "bloodType": bloodType,
      if (allergies != null) "allergies": allergies,
    };
  }
}

int? _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _normalizedUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final normalized = MediaUrl.normalize(value).trim();
  return normalized.isEmpty ? null : normalized;
}
