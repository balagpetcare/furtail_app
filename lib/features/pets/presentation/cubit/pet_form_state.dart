import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PetFormState {
  final bool loading;
  final bool success;
  final String? error;
  final int step;
  final bool showStep1Errors;

  // create/edit
  final int? petId;
  bool get editMode => petId != null;

  // ── Step 1: Basic Info ────────────────────────────────────────────────────
  final String name;
  final List<Map<String, dynamic>> animalTypes;
  final int? animalTypeId;
  final List<Map<String, dynamic>> breeds;
  final int? breedId;
  final String? customBreedText;
  final DateTime? dob;
  final int? ageYears;
  final String sex;
  final XFile? photo;
  final File? photoFile;
  final bool photoChanged;

  // ── Step 2: Appearance ───────────────────────────────────────────────────
  final int? colorId;
  final int? coatPatternId;
  final int? sizeId;
  final String? customColorText;

  // ── Step 3: Health ───────────────────────────────────────────────────────
  final String microchipNumber;
  final bool isRescue;
  final bool isNeutered;
  final String? bloodType;
  final String healthDisorders;
  final String allergiesText; // comma-separated for UI

  // ── Step 4: Lifestyle ────────────────────────────────────────────────────
  final String foodHabits;
  final String notes;
  final double? weightKg;

  // ── Step 5: Public Profile ───────────────────────────────────────────────
  final bool isPublicProfileEnabled;
  final String slug;
  final String bio;
  final File? coverPhotoFile;
  final bool coverPhotoChanged;
  final XFile? coverPhoto;
  final int? coverMediaId;
  final String? coverMediaUrl;

  static const int totalSteps = 6;

  const PetFormState({
    required this.loading,
    required this.success,
    required this.error,
    required this.step,
    required this.showStep1Errors,
    required this.petId,
    required this.name,
    required this.animalTypes,
    required this.animalTypeId,
    required this.breeds,
    required this.breedId,
    required this.customBreedText,
    required this.dob,
    required this.ageYears,
    required this.sex,
    required this.photo,
    required this.photoFile,
    required this.photoChanged,
    required this.colorId,
    required this.coatPatternId,
    required this.sizeId,
    required this.customColorText,
    required this.microchipNumber,
    required this.isRescue,
    required this.isNeutered,
    required this.bloodType,
    required this.healthDisorders,
    required this.allergiesText,
    required this.foodHabits,
    required this.notes,
    required this.weightKg,
    required this.isPublicProfileEnabled,
    required this.slug,
    required this.bio,
    required this.coverPhotoFile,
    required this.coverPhotoChanged,
    required this.coverPhoto,
    required this.coverMediaId,
    required this.coverMediaUrl,
  });

  factory PetFormState.initial({int? petId}) {
    return const PetFormState(
      loading: false,
      success: false,
      error: null,
      step: 0,
      showStep1Errors: false,
      petId: null,
      name: "",
      animalTypes: [],
      animalTypeId: null,
      breeds: [],
      breedId: null,
      customBreedText: null,
      dob: null,
      ageYears: null,
      sex: "UNKNOWN",
      photo: null,
      photoFile: null,
      photoChanged: false,
      colorId: null,
      coatPatternId: null,
      sizeId: null,
      customColorText: null,
      microchipNumber: "",
      isRescue: false,
      isNeutered: false,
      bloodType: null,
      healthDisorders: "",
      allergiesText: "",
      foodHabits: "",
      notes: "",
      weightKg: null,
      isPublicProfileEnabled: false,
      slug: "",
      bio: "",
      coverPhotoFile: null,
      coverPhotoChanged: false,
      coverPhoto: null,
      coverMediaId: null,
      coverMediaUrl: null,
    ).copyWith(petId: petId);
  }

  bool get basicValid => name.trim().isNotEmpty && animalTypeId != null;

  PetFormState copyWith({
    bool? loading,
    bool? success,
    String? error,
    int? step,
    bool? showStep1Errors,
    int? petId,
    String? name,
    List<Map<String, dynamic>>? animalTypes,
    int? animalTypeId,
    List<Map<String, dynamic>>? breeds,
    int? breedId,
    String? customBreedText,
    DateTime? dob,
    int? ageYears,
    String? sex,
    XFile? photo,
    File? photoFile,
    bool? photoChanged,
    int? colorId,
    int? coatPatternId,
    int? sizeId,
    String? customColorText,
    String? microchipNumber,
    bool? isRescue,
    bool? isNeutered,
    String? bloodType,
    String? healthDisorders,
    String? allergiesText,
    String? foodHabits,
    String? notes,
    double? weightKg,
    bool? isPublicProfileEnabled,
    String? slug,
    String? bio,
    File? coverPhotoFile,
    bool? coverPhotoChanged,
    XFile? coverPhoto,
    int? coverMediaId,
    String? coverMediaUrl,
  }) {
    return PetFormState(
      loading: loading ?? this.loading,
      success: success ?? this.success,
      error: error,
      step: step ?? this.step,
      showStep1Errors: showStep1Errors ?? this.showStep1Errors,
      petId: petId ?? this.petId,
      name: name ?? this.name,
      animalTypes: animalTypes ?? this.animalTypes,
      animalTypeId: animalTypeId ?? this.animalTypeId,
      breeds: breeds ?? this.breeds,
      breedId: breedId ?? this.breedId,
      customBreedText: customBreedText ?? this.customBreedText,
      dob: dob ?? this.dob,
      ageYears: ageYears ?? this.ageYears,
      sex: sex ?? this.sex,
      photo: photo ?? this.photo,
      photoFile: photoFile ?? this.photoFile,
      photoChanged: photoChanged ?? this.photoChanged,
      colorId: colorId ?? this.colorId,
      coatPatternId: coatPatternId ?? this.coatPatternId,
      sizeId: sizeId ?? this.sizeId,
      customColorText: customColorText ?? this.customColorText,
      microchipNumber: microchipNumber ?? this.microchipNumber,
      isRescue: isRescue ?? this.isRescue,
      isNeutered: isNeutered ?? this.isNeutered,
      bloodType: bloodType ?? this.bloodType,
      healthDisorders: healthDisorders ?? this.healthDisorders,
      allergiesText: allergiesText ?? this.allergiesText,
      foodHabits: foodHabits ?? this.foodHabits,
      notes: notes ?? this.notes,
      weightKg: weightKg ?? this.weightKg,
      isPublicProfileEnabled: isPublicProfileEnabled ?? this.isPublicProfileEnabled,
      slug: slug ?? this.slug,
      bio: bio ?? this.bio,
      coverPhotoFile: coverPhotoFile ?? this.coverPhotoFile,
      coverPhotoChanged: coverPhotoChanged ?? this.coverPhotoChanged,
      coverPhoto: coverPhoto ?? this.coverPhoto,
      coverMediaId: coverMediaId ?? this.coverMediaId,
      coverMediaUrl: coverMediaUrl ?? this.coverMediaUrl,
    );
  }
}
