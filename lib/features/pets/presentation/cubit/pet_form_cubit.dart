import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bpa_app/core/analytics/analytics_provider.dart';

import '../../domain/entities/pet_entity.dart';
import '../providers/pet_providers.dart';
import 'pet_form_state.dart';

final petFormProvider = AutoDisposeNotifierProviderFamily<PetFormController, PetFormState, int?>(
  PetFormController.new,
);

class PetFormController extends AutoDisposeFamilyNotifier<PetFormState, int?> {
  @override
  PetFormState build(int? petId) {
    // Kick off initial load
    scheduleMicrotask(() async {
      await init();
      await loadIfEdit();
    });

    return PetFormState.initial(petId: petId);
  }

  Future<void> init() async {
    state = state.copyWith(loading: true, error: null, success: false);
    try {
      final types = await ref.read(getAnimalTypesUsecaseProvider)();
      state = state.copyWith(animalTypes: types, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadIfEdit() async {
    if (!state.editMode) return;

    state = state.copyWith(loading: true, error: null, success: false);
    try {
      final list = await ref.read(getPetsUsecaseProvider)();
      final pet = list.firstWhere((p) => p.id == state.petId);

      final breeds = await ref.read(getBreedsUsecaseProvider)(pet.animalTypeId);

      int? ageYears;
      if (pet.dateOfBirth != null) {
        final now = DateTime.now();
        final dob = pet.dateOfBirth!;
        ageYears = now.year - dob.year - ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
      }

      state = state.copyWith(
        loading: false,
        breeds: breeds,
        name: pet.name,
        animalTypeId: pet.animalTypeId,
        breedId: pet.breedId,
        dob: pet.dateOfBirth,
        ageYears: ageYears,
        sex: pet.sex,
        isRescue: pet.isRescue,
        isNeutered: pet.isNeutered,
        weightKg: pet.weightKg,
        microchipNumber: pet.microchipNumber ?? "",
        foodHabits: pet.foodHabits ?? "",
        healthDisorders: pet.healthDisorders ?? "",
        notes: pet.notes ?? "",
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  // ---- Wizard navigation ----
  void next() => state = state.copyWith(step: state.step + 1, error: null);
  void back() => state = state.copyWith(step: (state.step - 1).clamp(0, 999), error: null);

  // ---- Field setters ----
  void setName(String v) => state = state.copyWith(name: v, error: null);
  void setBreed(int? id) => state = state.copyWith(breedId: id, error: null);
  void setAgeYears(int? v) => state = state.copyWith(ageYears: v, error: null);
  void setDob(DateTime? v) => state = state.copyWith(dob: v, error: null);
  void setSex(String v) => state = state.copyWith(sex: v, error: null);
  void setRescue(bool v) => state = state.copyWith(isRescue: v, error: null);
  void setNeutered(bool v) => state = state.copyWith(isNeutered: v, error: null);
  void setWeight(double? v) => state = state.copyWith(weightKg: v, error: null);
  void setMicrochip(String v) => state = state.copyWith(microchipNumber: v, error: null);
  void setFood(String v) => state = state.copyWith(foodHabits: v, error: null);
  void setHealth(String v) => state = state.copyWith(healthDisorders: v, error: null);
  void setNotes(String v) => state = state.copyWith(notes: v, error: null);

  void setPhoto(XFile file) => onPhotoSelected(file);
  void removePhoto() => state = state.copyWith(photo: null, photoFile: null, photoChanged: true);

  void onPhotoSelected(XFile file) {
    // Keep both XFile (UI) + File (upload)
    state = state.copyWith(photo: file, photoFile: File(file.path), photoChanged: true);
  }

  Future<void> setAnimalType(int? id) async {
    state = state.copyWith(animalTypeId: id, breedId: null, breeds: [], loading: true, error: null);
    if (id == null) {
      state = state.copyWith(loading: false);
      return;
    }

    try {
      final breeds = await ref.read(getBreedsUsecaseProvider)(id);
      state = state.copyWith(breeds: breeds, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> submit() async {
    if (!state.basicValid) {
      state = state.copyWith(error: "Required fields missing");
      return;
    }

    state = state.copyWith(loading: true, error: null, success: false);
    try {
      final micro = state.microchipNumber.trim();
      final food = state.foodHabits.trim();
      final health = state.healthDisorders.trim();
      final notes = state.notes.trim();

      final pet = PetEntity(
        id: state.petId,
        name: state.name.trim(),
        animalTypeId: state.animalTypeId!,
        breedId: state.breedId,
        dateOfBirth: state.dob,
                sex: state.sex,
        isRescue: state.isRescue,
        isNeutered: state.isNeutered,
        weightKg: state.weightKg,
        microchipNumber: micro.isEmpty ? null : micro,
        foodHabits: food.isEmpty ? null : food,
        healthDisorders: health.isEmpty ? null : health,
        notes: notes.isEmpty ? null : notes,
        photo: state.photo != null ? File(state.photo!.path) : null,
      );

      int petId;

      if (state.editMode) {
        petId = state.petId!;
        await ref.read(updatePetUsecaseProvider)(petId, pet);
      } else {
        petId = await ref.read(createPetUsecaseProvider)(pet);
        state = state.copyWith(petId: petId);
        await ref.read(analyticsServiceProvider).logPetCreated(petId: petId);
      }

      // Upload photo if changed
      if (state.photoChanged && state.photoFile != null) {
        await ref.read(uploadPetPhotoUsecaseProvider)(petId, state.photoFile!);
      }

      state = state.copyWith(loading: false, success: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}


// Backward-compatible alias (older widgets used PetFormCubit name)
typedef PetFormCubit = PetFormController;
