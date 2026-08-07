import '../entities/pet_entity.dart';
import '../repositories/pet_repository.dart';

class CreatePetUsecase {
  final PetRepository repo;
  CreatePetUsecase(this.repo);

  Future<PetEntity> call(PetEntity pet, {String? idempotencyKey}) =>
      repo.createPet(pet, idempotencyKey: idempotencyKey);
}
