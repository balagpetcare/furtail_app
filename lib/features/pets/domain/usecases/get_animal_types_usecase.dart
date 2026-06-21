import '../repositories/pet_repository.dart';

class GetAnimalTypesUsecase {
  final PetRepository repo;
  GetAnimalTypesUsecase(this.repo);

  Future<List<Map<String, dynamic>>> call() => repo.getAnimalTypes();
}
