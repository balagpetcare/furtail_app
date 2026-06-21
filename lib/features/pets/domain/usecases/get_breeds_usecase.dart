import '../repositories/pet_repository.dart';

class GetBreedsUsecase {
  final PetRepository repo;
  GetBreedsUsecase(this.repo);

  Future<List<Map<String, dynamic>>> call(int typeId) => repo.getBreeds(typeId);
}
