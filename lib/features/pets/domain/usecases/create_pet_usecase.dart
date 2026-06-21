import '../entities/pet_entity.dart';
import '../repositories/pet_repository.dart';

class CreatePetUsecase {
  final PetRepository repo;
  CreatePetUsecase(this.repo);

  Future<int> call(PetEntity pet) => repo.createPet(pet);
}
