import '../repositories/pet_repository.dart';

class UpdatePetPublicProfileUsecase {
  final PetRepository repo;
  UpdatePetPublicProfileUsecase(this.repo);

  Future<void> call(int petId, Map<String, dynamic> data) =>
      repo.updatePetPublicProfile(petId, data);
}
