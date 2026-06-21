import 'dart:io';
import '../entities/pet_entity.dart';

abstract class PetRepository {
  Future<List<Map<String, dynamic>>> getAnimalTypes();
  Future<List<Map<String, dynamic>>> getBreeds(int typeId);

  Future<List<PetEntity>> getAllPets();
  Future<int> createPet(PetEntity pet);
  Future<void> updatePet(int petId, PetEntity pet);

  // ✅ upload only photo -> returns mediaId
  Future<int> uploadPetPhoto(File file);

  // ✅ helper: upload photo + attach to pet
  Future<void> updatePetPhoto(int petId, File file);
}
