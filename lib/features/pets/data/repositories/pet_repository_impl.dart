import 'dart:io';

import '../../domain/entities/pet_entity.dart';
import '../../domain/repositories/pet_repository.dart';
import '../datasources/pet_remote_ds.dart';
import '../models/pet_model.dart';
import '../pet_service.dart';

class PetRepositoryImpl implements PetRepository {
  final PetRemoteDs remote;
  final PetService _service = PetService();

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
      subBreedId: pet.subBreedId,
      colorId: pet.colorId,
      coatPatternId: pet.coatPatternId,
      sizeId: pet.sizeId,
      customBreedText: pet.customBreedText,
      customColorText: pet.customColorText,
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
      bloodType: pet.bloodType,
      allergies: pet.allergies,
    ).toPayload();

    return remote.registerPetWithOptionalPhoto(
      payload: payload,
      photoFile: pet.photo,
    );
  }

  @override
  Future<void> updatePet(int petId, PetEntity pet) {
    final payload = PetModel(
      id: petId,
      name: pet.name,
      animalTypeId: pet.animalTypeId,
      breedId: pet.breedId,
      subBreedId: pet.subBreedId,
      colorId: pet.colorId,
      coatPatternId: pet.coatPatternId,
      sizeId: pet.sizeId,
      customBreedText: pet.customBreedText,
      customColorText: pet.customColorText,
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
      bloodType: pet.bloodType,
      allergies: pet.allergies,
    ).toPayload();

    return remote.updatePet(petId, payload);
  }

  @override
  Future<int> uploadPetPhoto(File file) => remote.uploadMedia(file);

  @override
  Future<void> updatePetPhoto(int petId, File file) async {
    final mediaId = await remote.uploadMedia(file);
    await remote.updatePet(petId, {"profilePicId": mediaId});
  }

  @override
  Future<void> updatePetPublicProfile(
      int petId, Map<String, dynamic> data) async {
    await _service.updatePetPublicProfile(petId, data);
  }

  @override
  Future<void> uploadPetCoverPhoto(int petId, File file) async {
    final mediaId = await remote.uploadMedia(file);
    await _service.updatePetPublicProfile(petId, {"coverMediaId": mediaId});
  }

  @override
  Future<PetEntity> getPublicPet(int petId) =>
      _service.getPublicPet(petId);

  @override
  Future<Map<String, dynamic>> getPetSocialStatus(int petId) =>
      _service.getPetSocialStatus(petId);

  @override
  Future<void> followPet(int petId) => _service.followPet(petId);

  @override
  Future<void> unfollowPet(int petId) => _service.unfollowPet(petId);

  @override
  Future<void> likePet(int petId) => _service.likePet(petId);

  @override
  Future<void> unlikePet(int petId) => _service.unlikePet(petId);

  @override
  Future<List<Map<String, dynamic>>> getPetPosts(int petId, {int? cursor}) =>
      _service.getPetPosts(petId, cursor: cursor);

  @override
  Future<Map<String, dynamic>> createPetPost(
          int petId, Map<String, dynamic> payload) =>
      _service.createPetPost(petId, payload);
}
