import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:furtail_app/core/analytics/analytics_provider.dart';

import '../../domain/entities/pet_entity.dart';
import '../providers/pet_providers.dart';
import 'pet_form_state.dart';

final petFormProvider =
    AutoDisposeNotifierProviderFamily<PetFormController, PetFormState, int?>(
      PetFormController.new,
    );

class PetFormController extends AutoDisposeFamilyNotifier<PetFormState, int?> {
  @override
  PetFormState build(int? petId) {
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
      final pet = list.cast<PetEntity?>().firstWhere(
        (candidate) => candidate?.id == state.petId,
        orElse: () => null,
      );
      if (pet == null) {
        throw StateError('Unable to find that pet. Refresh and try again.');
      }

      final breeds = await ref.read(getBreedsUsecaseProvider)(pet.animalTypeId);
      final breedBelongsToType =
          pet.breedId == null || breeds.any((b) => b['id'] == pet.breedId);

      int? ageYears;
      if (pet.dateOfBirth != null) {
        final now = DateTime.now();
        final dob = pet.dateOfBirth!;
        ageYears =
            now.year -
            dob.year -
            ((now.month < dob.month ||
                    (now.month == dob.month && now.day < dob.day))
                ? 1
                : 0);
      }

      state = state.copyWith(
        loading: false,
        breeds: breeds,
        name: pet.name,
        version: pet.version,
        animalTypeId: pet.animalTypeId,
        breedId: breedBelongsToType ? pet.breedId : null,
        dob: pet.dateOfBirth,
        ageYears: ageYears,
        sex: pet.sex,
        isRescue: pet.isRescue,
        isNeutered: pet.isNeutered,
        weightKg: pet.weightKg,
        uploadedProfileImageId: pet.profilePicId,
        microchipNumber: pet.microchipNumber ?? "",
        foodHabits: pet.foodHabits ?? "",
        healthDisorders: pet.healthDisorders ?? "",
        notes: pet.notes ?? "",
        bloodType: pet.bloodType,
        allergiesText: (pet.allergies ?? []).join(", "),
        slug: pet.slug ?? "",
        bio: pet.bio ?? "",
        isPublicProfileEnabled: pet.isPublicProfileEnabled ?? false,
        coverMediaId: pet.coverMediaId,
        coverMediaUrl: pet.coverMediaUrl,
        error: breedBelongsToType
            ? null
            : "This pet has a legacy breed value. Choose a canonical breed before saving.",
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  // ── Wizard navigation ─────────────────────────────────────────────────────
  void next() {
    if (state.step == 0) {
      if (state.name.trim().isEmpty || state.animalTypeId == null) {
        state = state.copyWith(
          showStep1Errors: true,
          error: "Name and Animal Type are required",
        );
        return;
      }
    }
    state = state.copyWith(
      step: state.step + 1,
      error: null,
      showStep1Errors: false,
    );
  }

  void back() {
    state = state.copyWith(step: (state.step - 1).clamp(0, 999), error: null);
  }

  // ── Step 1: Basic Info ────────────────────────────────────────────────────
  void setName(String v) => state = state.copyWith(name: v, error: null);
  void setDob(DateTime? v) => state = state.copyWith(dob: v, error: null);
  void setAgeYears(int? v) => state = state.copyWith(ageYears: v, error: null);
  void setSex(String v) => state = state.copyWith(sex: v, error: null);
  void setCustomBreed(String? v) =>
      state = state.copyWith(customBreedText: v, error: null);
  void setPhoto(XFile file) {
    state = state.copyWith(
      photo: file,
      photoFile: File(file.path),
      photoChanged: true,
      clearUploadedProfileImageId: true,
    );
  }

  void removePhoto() => state = state.copyWith(
    clearPhoto: true,
    clearPhotoFile: true,
    photoChanged: true,
  );

  Future<void> setAnimalType(int? id) async {
    state = state.copyWith(
      animalTypeId: id,
      clearAnimalTypeId: id == null,
      clearBreedId: true,
      clearCustomBreedText: true,
      breeds: [],
      loading: true,
      error: null,
    );
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

  void setBreed(int? id) => state = state.copyWith(breedId: id, error: null);

  // ── Step 2: Appearance ────────────────────────────────────────────────────
  void setColorId(int? v) => state = state.copyWith(colorId: v, error: null);
  void setCoatPatternId(int? v) =>
      state = state.copyWith(coatPatternId: v, error: null);
  void setSizeId(int? v) => state = state.copyWith(sizeId: v, error: null);
  void setCustomColor(String? v) =>
      state = state.copyWith(customColorText: v, error: null);

  // ── Step 3: Health ────────────────────────────────────────────────────────
  void setMicrochip(String v) =>
      state = state.copyWith(microchipNumber: v, error: null);
  void setRescue(bool v) => state = state.copyWith(isRescue: v, error: null);
  void setNeutered(bool v) =>
      state = state.copyWith(isNeutered: v, error: null);
  void setBloodType(String? v) =>
      state = state.copyWith(bloodType: v, error: null);
  void setHealth(String v) =>
      state = state.copyWith(healthDisorders: v, error: null);
  void setAllergies(String v) =>
      state = state.copyWith(allergiesText: v, error: null);

  // ── Step 4: Lifestyle ─────────────────────────────────────────────────────
  void setFood(String v) => state = state.copyWith(foodHabits: v, error: null);
  void setNotes(String v) => state = state.copyWith(notes: v, error: null);
  void setWeight(double? v) => state = state.copyWith(weightKg: v, error: null);

  // ── Step 5: Public Profile ────────────────────────────────────────────────
  void setPublicProfile(bool v) =>
      state = state.copyWith(isPublicProfileEnabled: v, error: null);
  void setSlug(String v) => state = state.copyWith(
    slug: v.toLowerCase().replaceAll(' ', '-'),
    error: null,
  );
  void setBio(String v) => state = state.copyWith(bio: v, error: null);
  void setCoverPhoto(XFile file) {
    state = state.copyWith(
      coverPhoto: file,
      coverPhotoFile: File(file.path),
      coverPhotoChanged: true,
    );
  }

  void setCoverPhotoFile(File file) {
    state = state.copyWith(
      coverPhoto: null,
      coverPhotoFile: file,
      coverPhotoChanged: true,
    );
  }

  void removeCoverPhoto() => state = state.copyWith(
    clearCoverPhoto: true,
    clearCoverPhotoFile: true,
    coverPhotoChanged: true,
  );

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> submit() async {
    if (state.loading) return;

    if (!state.basicValid) {
      state = state.copyWith(error: "Name and Animal Type are required");
      return;
    }

    state = state.copyWith(loading: true, error: null, success: false);
    try {
      final allergiesList = state.allergiesText
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final createIdempotencyKey =
          state.createIdempotencyKey ?? _newCreateIdempotencyKey();
      int? uploadedProfileImageId = state.uploadedProfileImageId;
      if (!state.editMode &&
          state.photoFile != null &&
          uploadedProfileImageId == null) {
        uploadedProfileImageId = await ref.read(uploadPetMediaIdProvider)(
          state.photoFile!,
        );
        state = state.copyWith(
          uploadedProfileImageId: uploadedProfileImageId,
          createIdempotencyKey: createIdempotencyKey,
        );
      }

      final pet = PetEntity(
        id: state.petId,
        name: state.name.trim(),
        version: state.version,
        animalTypeId: state.animalTypeId!,
        breedId: state.breedId,
        customBreedText: state.breedId == null
            ? null
            : state.customBreedText?.trim(),
        dateOfBirth: state.dob,
        sex: state.sex,
        isRescue: state.isRescue,
        isNeutered: state.isNeutered,
        weightKg: state.weightKg,
        microchipNumber: state.microchipNumber.trim().isEmpty
            ? null
            : state.microchipNumber.trim(),
        foodHabits: state.foodHabits.trim().isEmpty
            ? null
            : state.foodHabits.trim(),
        healthDisorders: state.healthDisorders.trim().isEmpty
            ? null
            : state.healthDisorders.trim(),
        notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
        photo: state.editMode ? state.photoFile : null,
        profilePicId: uploadedProfileImageId,
        clearProfileImage:
            state.editMode && state.photoChanged && state.photoFile == null,
        bloodType: state.bloodType?.trim(),
        allergies: allergiesList.isEmpty ? null : allergiesList,
      );

      int petId;

      if (state.editMode) {
        petId = state.petId!;
        await ref.read(updatePetUsecaseProvider)(petId, pet);
        unawaited(ref.read(ownerPetListProvider.notifier).refresh());
      } else {
        final createdPet = await ref.read(createPetUsecaseProvider)(
          pet,
          idempotencyKey: createIdempotencyKey,
        );
        petId = createdPet.id ?? 0;
        if (petId <= 0) {
          throw StateError(
            'Pet creation did not return a valid canonical pet id.',
          );
        }
        state = state.copyWith(petId: petId);
        ref.read(ownerPetListProvider.notifier).upsert(createdPet);
        unawaited(ref.read(ownerPetListProvider.notifier).refresh());
        await ref.read(analyticsServiceProvider).logPetCreated(petId: petId);
      }

      // Update public profile if enabled
      if (state.isPublicProfileEnabled ||
          state.slug.trim().isNotEmpty ||
          state.bio.trim().isNotEmpty) {
        final profilePayload = <String, dynamic>{
          "isPublicProfileEnabled": state.isPublicProfileEnabled,
          if (state.slug.trim().isNotEmpty) "slug": state.slug.trim(),
          if (state.bio.trim().isNotEmpty) "bio": state.bio.trim(),
        };
        await ref.read(updatePetPublicProfileUsecaseProvider)(
          petId,
          profilePayload,
        );
      }

      // Upload cover photo
      if (state.coverPhotoChanged && state.coverPhotoFile != null) {
        await ref.read(uploadPetCoverPhotoUsecaseProvider)(
          petId,
          state.coverPhotoFile!,
        );
      }

      state = state.copyWith(loading: false, success: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  String _newCreateIdempotencyKey() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'furtail-owner-pet-$millis-$random';
  }
}

typedef PetFormCubit = PetFormController;
