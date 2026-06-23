import 'dart:io';
import '../entities/pet_entity.dart';

abstract class PetRepository {
  Future<List<Map<String, dynamic>>> getAnimalTypes();
  Future<List<Map<String, dynamic>>> getBreeds(int typeId);

  Future<List<PetEntity>> getAllPets();
  Future<int> createPet(PetEntity pet);
  Future<void> updatePet(int petId, PetEntity pet);

  Future<int> uploadPetPhoto(File file);
  Future<void> updatePetPhoto(int petId, File file);

  // Social profile
  Future<void> updatePetPublicProfile(int petId, Map<String, dynamic> data);
  Future<void> uploadPetCoverPhoto(int petId, File file);

  // Public pet
  Future<PetEntity> getPublicPet(int petId);
  Future<Map<String, dynamic>> getPetSocialStatus(int petId);
  Future<void> followPet(int petId);
  Future<void> unfollowPet(int petId);
  Future<void> likePet(int petId);
  Future<void> unlikePet(int petId);
  Future<List<Map<String, dynamic>>> getPetPosts(int petId, {int? cursor});
  Future<Map<String, dynamic>> createPetPost(
      int petId, Map<String, dynamic> payload);
}
