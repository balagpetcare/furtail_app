import 'dart:io';
import '../repositories/pet_repository.dart';

class UploadPetCoverPhotoUsecase {
  final PetRepository repo;
  UploadPetCoverPhotoUsecase(this.repo);

  Future<void> call(int petId, File file) =>
      repo.uploadPetCoverPhoto(petId, file);
}
