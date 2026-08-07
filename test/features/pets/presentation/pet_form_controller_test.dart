import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/pets/data/models/pet_model.dart';
import 'package:furtail_app/features/pets/domain/entities/pet_entity.dart';
import 'package:furtail_app/features/pets/domain/repositories/pet_repository.dart';
import 'package:furtail_app/features/pets/domain/usecases/create_pet_usecase.dart';
import 'package:furtail_app/features/pets/domain/usecases/get_animal_types_usecase.dart';
import 'package:furtail_app/features/pets/domain/usecases/get_breeds_usecase.dart';
import 'package:furtail_app/features/pets/domain/usecases/get_pets_usecase.dart';
import 'package:furtail_app/features/pets/domain/usecases/update_pet_usecase.dart';
import 'package:furtail_app/features/pets/domain/usecases/update_pet_public_profile_usecase.dart';
import 'package:furtail_app/features/pets/domain/usecases/upload_pet_cover_photo_usecase.dart';
import 'package:furtail_app/features/pets/presentation/cubit/pet_form_cubit.dart';
import 'package:furtail_app/features/pets/presentation/cubit/pet_form_state.dart';
import 'package:furtail_app/features/pets/presentation/providers/pet_providers.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:image_picker/image_picker.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(dio: Dio());

  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    return {
      'success': true,
      'data': {'items': const []},
    };
  }
}

class _FakePetRepository implements PetRepository {
  int uploadCount = 0;
  int createCount = 0;
  int updateCount = 0;
  final List<String?> createKeys = <String?>[];
  PetEntity? lastCreatedPet;
  Object? uploadError;
  Object? createError;
  int uploadedMediaId = 77;
  final List<PetEntity> createdPets = <PetEntity>[
    const PetModel(
      id: 42,
      name: 'Milo',
      animalTypeId: 1,
      breedId: 2,
      profilePicId: 77,
      weightKg: 4.3,
      customColorText: 'Black white brown',
    ),
  ];

  @override
  Future<List<Map<String, dynamic>>> getAnimalTypes() async => const [
    {'id': 1, 'name': 'Dog'},
  ];

  @override
  Future<List<Map<String, dynamic>>> getBreeds(int typeId) async => const [
    {'id': 2, 'name': 'Local'},
  ];

  @override
  Future<List<PetEntity>> getAllPets() async => const [];

  @override
  Future<PetEntity> createPet(PetEntity pet, {String? idempotencyKey}) async {
    createCount += 1;
    createKeys.add(idempotencyKey);
    lastCreatedPet = pet;
    if (createError != null && createCount == 1) {
      throw createError!;
    }
    return createdPets[(createCount - 1).clamp(0, createdPets.length - 1)];
  }

  @override
  Future<void> updatePet(int petId, PetEntity pet) async {
    updateCount += 1;
  }

  @override
  Future<int> uploadPetPhoto(File file) async {
    uploadCount += 1;
    if (uploadError != null) throw uploadError!;
    return uploadedMediaId;
  }

  @override
  Future<void> updatePetPhoto(int petId, File file, {int? version}) async {}

  @override
  Future<void> removePetPhoto(int petId, {int? version}) async {}

  @override
  Future<void> updatePetPublicProfile(
    int petId,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> uploadPetCoverPhoto(int petId, File file) async {}

  @override
  Future<PetEntity> getPublicPet(int petId) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getPetSocialStatus(int petId) async =>
      throw UnimplementedError();

  @override
  Future<void> followPet(int petId) async {}

  @override
  Future<void> unfollowPet(int petId) async {}

  @override
  Future<void> likePet(int petId) async {}

  @override
  Future<void> unlikePet(int petId) async {}

  @override
  Future<List<Map<String, dynamic>>> getPetPosts(
    int petId, {
    int? cursor,
  }) async => const [];

  @override
  Future<Map<String, dynamic>> createPetPost(
    int petId,
    Map<String, dynamic> payload,
  ) async => const {};
}

ProviderContainer _containerFor(_FakePetRepository repo) {
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(_FakeApiClient()),
      getAnimalTypesUsecaseProvider.overrideWithValue(
        GetAnimalTypesUsecase(repo),
      ),
      getBreedsUsecaseProvider.overrideWithValue(GetBreedsUsecase(repo)),
      getPetsUsecaseProvider.overrideWithValue(GetPetsUsecase(repo)),
      createPetUsecaseProvider.overrideWithValue(CreatePetUsecase(repo)),
      updatePetUsecaseProvider.overrideWithValue(UpdatePetUsecase(repo)),
      uploadPetMediaIdProvider.overrideWithValue(repo.uploadPetPhoto),
      updatePetPublicProfileUsecaseProvider.overrideWithValue(
        UpdatePetPublicProfileUsecase(repo),
      ),
      uploadPetCoverPhotoUsecaseProvider.overrideWithValue(
        UploadPetCoverPhotoUsecase(repo),
      ),
    ],
  );
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'create retry preserves uploaded media and idempotency key without duplicate upload',
    () async {
      final repo = _FakePetRepository()
        ..createError = ApiClientException(message: 'Create failed');
      final container = _containerFor(repo);
      addTearDown(container.dispose);
      final subscription = container.listen<PetFormState>(
        petFormProvider(null),
        (_, __) {},
      );
      addTearDown(subscription.close);

      final notifier = container.read(petFormProvider(null).notifier);
      await _flush();

      notifier.setName('Milo');
      await notifier.setAnimalType(1);
      notifier.setBreed(2);
      notifier.setCustomColor('Black white brown');
      notifier.setWeight(4.3);
      notifier.setPhoto(XFile('D:/tmp/milo.jpg'));

      await notifier.submit();

      var state = container.read(petFormProvider(null));
      expect(state.success, isFalse);
      expect(state.photoFile?.path, 'D:/tmp/milo.jpg');
      expect(state.uploadedProfileImageId, 77);
      expect(state.createIdempotencyKey, isNotEmpty);
      expect(repo.uploadCount, 1);
      expect(repo.createCount, 1);

      await notifier.submit();

      state = container.read(petFormProvider(null));
      expect(state.success, isTrue);
      expect(repo.uploadCount, 1);
      expect(repo.createCount, 2);
      expect(repo.createKeys.first, isNotEmpty);
      expect(repo.createKeys.first, repo.createKeys.last);
      expect(repo.lastCreatedPet?.animalTypeId, 1);
      expect(repo.lastCreatedPet?.breedId, 2);
      expect(repo.lastCreatedPet?.profilePicId, 77);
      expect(repo.lastCreatedPet?.weightKg, 4.3);
      expect(container.read(ownerPetListProvider).pets.single.id, 42);
    },
  );

  test('upload failure preserves photo and blocks create', () async {
    final repo = _FakePetRepository()
      ..uploadError = ApiClientException(message: 'Upload failed');
    final container = _containerFor(repo);
    addTearDown(container.dispose);
    final subscription = container.listen<PetFormState>(
      petFormProvider(null),
      (_, __) {},
    );
    addTearDown(subscription.close);

    final notifier = container.read(petFormProvider(null).notifier);
    await _flush();

    notifier.setName('Nova');
    await notifier.setAnimalType(1);
    notifier.setPhoto(XFile('D:/tmp/nova.jpg'));

    await notifier.submit();

    final state = container.read(petFormProvider(null));
    expect(state.success, isFalse);
    expect(state.photoFile?.path, 'D:/tmp/nova.jpg');
    expect(state.uploadedProfileImageId, isNull);
    expect(repo.uploadCount, 1);
    expect(repo.createCount, 0);
  });
}
