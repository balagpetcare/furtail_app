import 'dart:io';

import 'package:furtail_app/features/common/data/repositories/animal_taxonomy_repository.dart';

import '../../domain/entities/pet_entity.dart';
import '../../domain/repositories/pet_repository.dart';
import '../datasources/pet_remote_ds.dart';
import '../models/pet_model.dart';
import '../pet_service.dart';

class PetRepositoryImpl implements PetRepository {
  final PetRemoteDs remote;
  final PetService _service;
  final AnimalTaxonomyRepository _taxonomy;

  PetRepositoryImpl(
    this.remote, {
    PetService? service,
    required AnimalTaxonomyRepository taxonomy,
  }) : _service = service ?? PetService(),
       _taxonomy = taxonomy;

  @override
  Future<List<Map<String, dynamic>>> getAnimalTypes() async {
    final types = await _taxonomy.getAnimalTypes();
    return types
        .map(
          (type) => {
            'id': type.id,
            'code': type.code,
            'name': type.name,
            'nameBn': type.nameBn,
            'icon': type.icon,
            'scientificName': type.scientificName,
            'displayOrder': type.displayOrder,
          },
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getBreeds(int typeId) async {
    final breeds = await _taxonomy.getBreeds(animalTypeId: typeId);
    return breeds
        .map(
          (breed) => {
            'id': breed.id,
            'code': breed.code,
            'name': breed.name,
            'nameBn': breed.nameBn,
            'animalTypeId': breed.animalTypeId,
            'aliasNames': breed.aliasNames,
            'isMixed': breed.isMixed,
            'isOther': breed.isOther,
            'isLocal': breed.isLocal,
            'isUnknown': breed.isUnknown,
            'displayOrder': breed.displayOrder,
          },
        )
        .toList();
  }

  @override
  Future<List<PetEntity>> getAllPets() async {
    final list = await remote.getAllPets();
    return list.map<PetEntity>((e) => PetModel.fromJson(e)).toList();
  }

  @override
  Future<PetEntity> createPet(PetEntity pet, {String? idempotencyKey}) {
    final payload = PetModel(
      name: pet.name,
      version: pet.version,
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
      photoFile: pet.profilePicId == null ? pet.photo : null,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> updatePet(int petId, PetEntity pet) async {
    final payload = PetModel(
      id: petId,
      name: pet.name,
      version: pet.version,
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

    if (pet.photo != null) {
      payload["profileImageId"] = await remote.uploadMedia(pet.photo!);
    } else if (pet.clearProfileImage) {
      payload["profileImageId"] = null;
    }

    await remote.updatePet(petId, payload);
  }

  @override
  Future<int> uploadPetPhoto(File file) => remote.uploadMedia(file);

  @override
  Future<void> updatePetPhoto(int petId, File file, {int? version}) async {
    final mediaId = await remote.uploadMedia(file);
    await remote.updatePet(petId, {
      "profileImageId": mediaId,
      ...version == null ? const <String, dynamic>{} : {"version": version},
    });
  }

  @override
  Future<void> removePetPhoto(int petId, {int? version}) async {
    await remote.updatePet(petId, {
      "profileImageId": null,
      ...version == null ? const <String, dynamic>{} : {"version": version},
    });
  }

  @override
  Future<void> updatePetPublicProfile(
    int petId,
    Map<String, dynamic> data,
  ) async {
    await _service.updatePetPublicProfile(petId, data);
  }

  @override
  Future<void> uploadPetCoverPhoto(int petId, File file) async {
    final mediaId = await remote.uploadMedia(file);
    await _service.updatePetPublicProfile(petId, {"coverMediaId": mediaId});
  }

  @override
  Future<PetEntity> getPublicPet(int petId) => _service.getPublicPet(petId);

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
    int petId,
    Map<String, dynamic> payload,
  ) => _service.createPetPost(petId, payload);
}
