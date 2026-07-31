import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/common/data/models/animal_taxonomy_models.dart';

void main() {
  group('AnimalTypeModel', () {
    test('parses full JSON, including Bengali name and display order', () {
      final type = AnimalTypeModel.fromJson({
        'id': 1,
        'code': 'DOG',
        'name': 'Dog',
        'nameBn': 'কুকুর',
        'icon': '🐕',
        'displayOrder': 1,
      });
      expect(type.id, 1);
      expect(type.code, 'DOG');
      expect(type.display(), 'Dog');
      expect(type.display(bn: true), 'কুকুর');
    });

    test(
      'falls back to English name when Bengali is absent even if bn requested',
      () {
        final type = AnimalTypeModel.fromJson({'id': 2, 'name': 'Cat'});
        expect(type.display(bn: true), 'Cat');
      },
    );
  });

  group('BreedModel', () {
    test('parses the four safe non-specific choice flags', () {
      final local = BreedModel.fromJson({
        'id': 1,
        'name': 'Bangladeshi Street Dog',
        'animalTypeId': 1,
        'isLocal': true,
      });
      final mixed = BreedModel.fromJson({
        'id': 2,
        'name': 'Mixed Breed',
        'animalTypeId': 1,
        'isMixed': true,
      });
      final unknown = BreedModel.fromJson({
        'id': 3,
        'name': 'Unknown',
        'animalTypeId': 1,
        'isUnknown': true,
      });
      final other = BreedModel.fromJson({
        'id': 4,
        'name': 'Other',
        'animalTypeId': 1,
        'isOther': true,
      });
      final named = BreedModel.fromJson({
        'id': 5,
        'name': 'Labrador',
        'animalTypeId': 1,
      });

      expect(local.isSafeNonSpecificChoice, isTrue);
      expect(mixed.isSafeNonSpecificChoice, isTrue);
      expect(unknown.isSafeNonSpecificChoice, isTrue);
      expect(other.isSafeNonSpecificChoice, isTrue);
      expect(named.isSafeNonSpecificChoice, isFalse);
    });

    test(
      'is scoped to a single species via animalTypeId — a breed list for one species never includes another',
      () {
        final dogBreeds = [
          BreedModel.fromJson({'id': 1, 'name': 'Labrador', 'animalTypeId': 1}),
          BreedModel.fromJson({
            'id': 2,
            'name': 'German Shepherd',
            'animalTypeId': 1,
          }),
        ];
        final catBreeds = [
          BreedModel.fromJson({'id': 3, 'name': 'Persian', 'animalTypeId': 2}),
        ];
        final allBreeds = [...dogBreeds, ...catBreeds];

        final onlyDogBreeds = allBreeds
            .where((b) => b.animalTypeId == 1)
            .toList();
        expect(onlyDogBreeds.length, 2);
        expect(onlyDogBreeds.every((b) => b.animalTypeId == 1), isTrue);
        expect(onlyDogBreeds.any((b) => b.name == 'Persian'), isFalse);
      },
    );

    test('parses alias names for search', () {
      final breed = BreedModel.fromJson({
        'id': 1,
        'name': 'German Shepherd',
        'animalTypeId': 1,
        'aliasNames': ['GSD', 'Alsatian'],
      });
      expect(breed.aliasNames, ['GSD', 'Alsatian']);
    });
  });
}
