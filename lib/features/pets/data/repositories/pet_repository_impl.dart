import 'dart:io';

import '../../domain/entities/pet_entity.dart';
import '../../domain/repositories/pet_repository.dart';
import '../datasources/pet_remote_ds.dart';
import '../models/pet_model.dart';

class PetRepositoryImpl implements PetRepository {
  final PetRemoteDs remote;
  PetRepositoryImpl(this.remote);

  @override
  Future<List<Map<String, dynamic>>> getAnimalTypes() =>
      remote.getAnimalTypes();

  @override
  Future<List<Map<String, dynamic>>> getBreeds(int typeId) =>
      remote.getBreeds(typeId);

  @override
  Future<List<PetEntity>> getAllPets() async {
    final list = await remote.getAllPets();
    return list.map<PetEntity>((e) => PetModel.fromJson(e)).toList();
  }

  @override
  Future<int> createPet(PetEntity pet) {
    final payload = PetModel(
      name: pet.name,
      animalTypeId: pet.animalTypeId,
      breedId: pet.breedId,
      dateOfBirth: pet.dateOfBirth,
      sex: pet.sex,
      microchipNumber: pet.microchipNumber,
      isRescue: pet.isRescue,
      isNeutered: pet.isNeutered,
      foodHabits: pet.foodHabits,
      healthDisorders: pet.healthDisorders,
      notes: pet.notes,
      weightKg: pet.weightKg,
      profilePicId: pet.profilePicId, // old flow support
    ).toPayload();

    // ✅ NEW: photo pass through (single request pet+photo)
    return remote.registerPetWithOptionalPhoto(
      payload: payload,
      photoFile: pet.photo, // ✅ PetEntity.photo (File?)
    );
  }

  @override
  Future<void> updatePet(int petId, PetEntity pet) {
    final payload = PetModel(
      id: petId,
      name: pet.name,
      animalTypeId: pet.animalTypeId,
      breedId: pet.breedId,
      dateOfBirth: pet.dateOfBirth,
      sex: pet.sex,
      microchipNumber: pet.microchipNumber,
      isRescue: pet.isRescue,
      isNeutered: pet.isNeutered,
      foodHabits: pet.foodHabits,
      healthDisorders: pet.healthDisorders,
      notes: pet.notes,
      weightKg: pet.weightKg,
      profilePicId: pet.profilePicId,
    ).toPayload();

    return remote.updatePet(petId, payload);
  }

  // upload only photo -> returns mediaId (still supported)
  @override
  Future<int> uploadPetPhoto(File file) {
    return remote.uploadMedia(file);
  }

  // upload photo + update pet (still supported)
  @override
  Future<void> updatePetPhoto(int petId, File file) async {
    final mediaId = await remote.uploadMedia(file);
    await remote.updatePet(petId, {"profilePicId": mediaId});
  }
}
