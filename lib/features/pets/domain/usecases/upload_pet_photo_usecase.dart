import 'dart:io';
import '../repositories/pet_repository.dart';

class UpdatePetPhotoUsecase {
  final PetRepository repo;
  UpdatePetPhotoUsecase(this.repo);

  /// Uploads photo and attaches it to pet
  Future<void> call(int petId, File file, {int? version}) {
    return repo.updatePetPhoto(petId, file, version: version);
  }
}

class RemovePetPhotoUsecase {
  final PetRepository repo;
  RemovePetPhotoUsecase(this.repo);

  Future<void> call(int petId, {int? version}) {
    return repo.removePetPhoto(petId, version: version);
  }
}
