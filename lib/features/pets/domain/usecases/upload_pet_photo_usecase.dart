import 'dart:io';
import '../repositories/pet_repository.dart';

class UpdatePetPhotoUsecase {
  final PetRepository repo;
  UpdatePetPhotoUsecase(this.repo);

  /// Uploads photo and attaches it to pet
  Future<void> call(int petId, File file) {
    return repo.updatePetPhoto(petId, file);
  }
}
