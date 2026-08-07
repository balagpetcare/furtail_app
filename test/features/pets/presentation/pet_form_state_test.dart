import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/pets/presentation/cubit/pet_form_state.dart';

void main() {
  test('breed clears when animal type changes', () {
    final initial = PetFormState.initial().copyWith(
      animalTypeId: 1,
      breedId: 10,
      breeds: [
        {'id': 10, 'animalTypeId': 1, 'name': 'Local'},
      ],
    );

    final changed = initial.copyWith(
      animalTypeId: 2,
      breeds: const [],
      clearBreedId: true,
      clearCustomBreedText: true,
    );

    expect(changed.animalTypeId, 2);
    expect(changed.breedId, isNull);
    expect(changed.customBreedText, isNull);
    expect(changed.breeds, isEmpty);
  });

  test('explicit null image state is preserved for removal', () {
    final removed = PetFormState.initial(
      petId: 5,
    ).copyWith(clearPhoto: true, clearPhotoFile: true, photoChanged: true);

    expect(removed.editMode, isTrue);
    expect(removed.photo, isNull);
    expect(removed.photoFile, isNull);
    expect(removed.photoChanged, isTrue);
  });
}
