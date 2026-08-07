import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:furtail_app/features/pets/presentation/pet_profile_wizard_screen.dart';
import 'package:furtail_app/features/pets/presentation/providers/pet_providers.dart';
import 'package:furtail_app/services/api_client.dart';

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
  @override
  Future<List<Map<String, dynamic>>> getAnimalTypes() async => const [
    {'id': 1, 'name': 'Dog'},
  ];

  @override
  Future<List<Map<String, dynamic>>> getBreeds(int typeId) async => const [];

  @override
  Future<List<PetEntity>> getAllPets() async => const [];

  @override
  Future<PetEntity> createPet(PetEntity pet, {String? idempotencyKey}) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePet(int petId, PetEntity pet) async {}

  @override
  Future<int> uploadPetPhoto(file) async => 1;

  @override
  Future<void> updatePetPhoto(int petId, file, {int? version}) async {}

  @override
  Future<void> removePetPhoto(int petId, {int? version}) async {}

  @override
  Future<void> updatePetPublicProfile(
    int petId,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> uploadPetCoverPhoto(int petId, file) async {}

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

void main() {
  testWidgets('color and weight keep typed order and caret across rebuilds', (
    tester,
  ) async {
    final repo = _FakePetRepository();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        getAnimalTypesUsecaseProvider.overrideWithValue(
          GetAnimalTypesUsecase(repo),
        ),
        getBreedsUsecaseProvider.overrideWithValue(GetBreedsUsecase(repo)),
        getPetsUsecaseProvider.overrideWithValue(GetPetsUsecase(repo)),
        createPetUsecaseProvider.overrideWithValue(CreatePetUsecase(repo)),
        updatePetUsecaseProvider.overrideWithValue(UpdatePetUsecase(repo)),
        updatePetPublicProfileUsecaseProvider.overrideWithValue(
          UpdatePetPublicProfileUsecase(repo),
        ),
        uploadPetCoverPhotoUsecaseProvider.overrideWithValue(
          UploadPetCoverPhotoUsecase(repo),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PetProfileWizardScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final notifier = container.read(petFormProvider(null).notifier);
    notifier.setName('Milo');
    await notifier.setAnimalType(1);
    notifier.next();
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    final colorField = fields.at(0);
    await tester.enterText(colorField, 'Black white brown');
    await tester.pump();

    notifier.setColorId(5);
    await tester.pump();

    final colorWidget = tester.widget<TextFormField>(colorField);
    expect(colorWidget.controller?.text, 'Black white brown');
    expect(
      colorWidget.controller?.selection.extentOffset,
      'Black white brown'.length,
    );

    final weightField = fields.at(1);
    await tester.enterText(weightField, '4.3');
    await tester.pump();

    notifier.setSizeId(2);
    await tester.pump();

    final weightWidget = tester.widget<TextFormField>(weightField);
    expect(weightWidget.controller?.text, '4.3');
    expect(weightWidget.controller?.selection.extentOffset, 3);
    expect(container.read(petFormProvider(null)).weightKg, 4.3);
  });
}
