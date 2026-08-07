import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/pets/data/models/pet_model.dart';

void main() {
  test('canonical BPA-created pet renders and keeps IDs/version', () {
    final pet = PetModel.fromJson({
      'id': 42,
      'version': 7,
      'name': 'Buddy',
      'animalTypeId': 1,
      'animalTypeName': 'Dog',
      'breedId': 9,
      'breedName': 'Local',
      'profileImageId': 15,
      'weights': null,
    });

    expect(pet.id, 42);
    expect(pet.version, 7);
    expect(pet.animalTypeId, 1);
    expect(pet.breedId, 9);
    expect(pet.animalTypeName, 'Dog');
    expect(pet.breedName, 'Local');
    expect(pet.profilePicId, 15);
  });

  test('payload has canonical ids, version, image key, and no owner id', () {
    final payload = const PetModel(
      name: 'Milo',
      animalTypeId: 1,
      breedId: 2,
      version: 3,
      profilePicId: 4,
    ).toPayload();

    expect(payload['animalTypeId'], 1);
    expect(payload['breedId'], 2);
    expect(payload['version'], 3);
    expect(payload['profileImageId'], 4);
    expect(payload, isNot(contains('profilePicId')));
    expect(payload, isNot(contains('ownerUserId')));
    expect(payload, isNot(contains('userId')));
  });
}
