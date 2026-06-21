import '../entities/pet_entity.dart';
import '../repositories/pet_repository.dart';

class UpdatePetUsecase {
  final PetRepository repo;
  UpdatePetUsecase(this.repo);

  Future<void> call(int petId, PetEntity pet) => repo.updatePet(petId, pet);
}
