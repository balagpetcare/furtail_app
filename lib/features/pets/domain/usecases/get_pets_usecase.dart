import '../entities/pet_entity.dart';
import '../repositories/pet_repository.dart';

class GetPetsUsecase {
  final PetRepository repo;
  GetPetsUsecase(this.repo);

  Future<List<PetEntity>> call() => repo.getAllPets();
}
