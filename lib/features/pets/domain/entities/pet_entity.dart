import 'dart:io';

class PetEntity {
  final int? id;
  final String name;

  final int animalTypeId;
  final int? breedId;
  final int? subBreedId;
  final int? colorId;
  final int? coatPatternId;
  final int? sizeId;
  final String? customBreedText;
  final String? customColorText;
  final int? profilePicId;

  final File? photo;

  // UI display fields (snapshot names from API)
  final String? animalTypeName;
  final String? breedName;
  final String? colorName;
  final String? sizeName;
  final String? coatPatternName;

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
  final String? bloodType;
  final List<String>? allergies;

  // Social profile fields
  final String? slug;
  final String? bio;
  final int? coverMediaId;
  final String? coverMediaUrl;
  final bool? isPublicProfileEnabled;
  final String? visibility;
  final int? followersCount;
  final int? likesCount;

  // Social status (for visitor view)
  final bool? isFollowing;
  final bool? isLiked;
  final bool? isOwner;
  final bool? canManage;

  const PetEntity({
    this.id,
    required this.name,
    required this.animalTypeId,
    this.breedId,
    this.subBreedId,
    this.colorId,
    this.coatPatternId,
    this.sizeId,
    this.customBreedText,
    this.customColorText,
    this.animalTypeName,
    this.breedName,
    this.colorName,
    this.sizeName,
    this.coatPatternName,
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
    this.photo,
    this.bloodType,
    this.allergies,
    this.slug,
    this.bio,
    this.coverMediaId,
    this.coverMediaUrl,
    this.isPublicProfileEnabled,
    this.visibility,
    this.followersCount,
    this.likesCount,
    this.isFollowing,
    this.isLiked,
    this.isOwner,
    this.canManage,
  });

  String get animalType => animalTypeName ?? '';
  String get breed => breedName ?? '';
}
