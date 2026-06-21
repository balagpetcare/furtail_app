import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PetFormState {
  final bool loading;
  final bool success;
  final String? error;

  final int step;

  // create/edit
  final int? petId;
  bool get editMode => petId != null;

  // basic
  final String name;

  final List<Map<String, dynamic>> animalTypes;
  final int? animalTypeId;
  final XFile? photo; // 🔥 ADD THIS
  final List<Map<String, dynamic>> breeds;
  final int? breedId;

  final DateTime? dob;
  final int? ageYears;

  // details
  final String sex; // "MALE" | "FEMALE" | "UNKNOWN"
  final String microchipNumber; // UI input string (empty allowed)
  final bool isRescue;
  final bool isNeutered;

  final String foodHabits;
  final String healthDisorders;
  final String notes;

  final double? weightKg;

  // photo
  final File? photoFile;
  final bool photoChanged;

  const PetFormState({
    required this.loading,
    required this.success,
    required this.error,
    required this.step,
    required this.petId,
    required this.name,
    required this.animalTypes,
    required this.animalTypeId,
    required this.breeds,
    required this.breedId,
    required this.dob,
    required this.ageYears,
    required this.sex,
    required this.microchipNumber,
    required this.isRescue,
    required this.isNeutered,
    required this.foodHabits,
    required this.healthDisorders,
    required this.notes,
    required this.weightKg,
    required this.photoFile,
    required this.photoChanged,
    this.photo, // 🔥 ADD THIS
  });

  // ✅ Use THIS in Cubit super()
  factory PetFormState.initial({int? petId}) {
    return PetFormState(
      loading: false,
      success: false,
      error: null,
      step: 0,
      petId: petId,
      name: "",
      animalTypes: const [],
      animalTypeId: null,
      breeds: const [],
      breedId: null,
      dob: null,
      ageYears: null,
      sex: "UNKNOWN",
      microchipNumber: "",
      isRescue: false,
      isNeutered: false,
      foodHabits: "",
      healthDisorders: "",
      notes: "",
      weightKg: null,
      photoFile: null,
      photoChanged: false,
    );
  }

  bool get basicValid =>
      name.trim().isNotEmpty && animalTypeId != null;

  PetFormState copyWith({
    bool? loading,
    bool? success,
    String? error,
    int? step,
    int? petId,
    String? name,
    List<Map<String, dynamic>>? animalTypes,
    int? animalTypeId,
    List<Map<String, dynamic>>? breeds,
    int? breedId,
    DateTime? dob,
    int? ageYears,
    String? sex,
    String? microchipNumber,
    bool? isRescue,
    bool? isNeutered,
    String? foodHabits,
    String? healthDisorders,
    String? notes,
    double? weightKg,
    File? photoFile,
    bool? photoChanged,
    XFile? photo, // 🔥 ADD THIS
  }) {
    return PetFormState(
      loading: loading ?? this.loading,
      success: success ?? this.success,
      error: error,
      step: step ?? this.step,
      petId: petId ?? this.petId,
      name: name ?? this.name,
      animalTypes: animalTypes ?? this.animalTypes,
      animalTypeId: animalTypeId ?? this.animalTypeId,
      breeds: breeds ?? this.breeds,
      breedId: breedId ?? this.breedId,
      dob: dob ?? this.dob,
      ageYears: ageYears ?? this.ageYears,
      sex: sex ?? this.sex,
      microchipNumber: microchipNumber ?? this.microchipNumber,
      isRescue: isRescue ?? this.isRescue,
      isNeutered: isNeutered ?? this.isNeutered,
      foodHabits: foodHabits ?? this.foodHabits,
      healthDisorders: healthDisorders ?? this.healthDisorders,
      notes: notes ?? this.notes,
      weightKg: weightKg ?? this.weightKg,
      photoFile: photoFile ?? this.photoFile,
      photoChanged: photoChanged ?? this.photoChanged,
      photo: photo ?? this.photo, // 🔥 ADD THIS
    );
  }
}
