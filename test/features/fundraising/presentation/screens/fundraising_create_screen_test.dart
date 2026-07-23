import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_payout_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_create_screen.dart';
import 'package:furtail_app/features/media/composer/media_composer_controller.dart';
import 'package:furtail_app/features/media/composer/media_composer_policy.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:furtail_app/features/pets/domain/entities/pet_entity.dart';
import 'package:furtail_app/features/pets/domain/repositories/pet_repository.dart';
import 'package:furtail_app/features/pets/domain/usecases/get_pets_usecase.dart';
import 'package:furtail_app/features/pets/presentation/providers/pet_providers.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FundraisingCreateScreen', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp(
        'fundraising-create-screen-test-',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('shows inline validation for an incomplete story step', (
      tester,
    ) async {
      final recovery = _InMemoryRecoveryService(
        FundraisingDraftRecovery.empty().copyWith(
          stepIndex: FundraisingWizardStep.storyAndGoal.index,
          category: 'TREATMENT',
          beneficiaryType: 'PET',
          beneficiaryName: 'Tuni',
        ),
      );
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(),
        recoveryService: recovery,
      );
      final mediaController = MediaComposerController(
        policy: MediaComposerPolicy.fundraising,
        draftStorageKey: 'widget-validation',
        uploadMedia: _successfulUpload,
      );

      await _pumpScreen(
        tester,
        controller: controller,
        mediaController: mediaController,
      );

      await tester.tap(find.text('Continue'));
      await _settleUi(tester);

      expect(
        find.textContaining('campaign title with at least 6 characters'),
        findsOneWidget,
      );
      expect(
        find.textContaining('clear story with at least 40 characters'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FundraisingCreateWizardController controller,
  required MediaComposerController mediaController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        getPetsUsecaseProvider.overrideWithValue(
          GetPetsUsecase(_FakePetRepository()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FundraisingCreateScreen(
          controller: controller,
          mediaController: mediaController,
        ),
      ),
    ),
  );
  await _settleUi(tester);
}

Future<void> _settleUi(
  WidgetTester tester, {
  Duration extra = const Duration(milliseconds: 250),
}) async {
  await tester.pump();
  await tester.pump(extra);
}

class _FakeFundraisingRepository extends FundraisingRepository {
  _FakeFundraisingRepository({
    FundraisingAccount? account,
    List<FundraisingPayoutMethod>? payoutMethods,
  }) : _account = account ?? _verifiedAccount,
       _payoutMethods = payoutMethods ?? _activePayoutMethods,
       super(ApiClient(dio: Dio()));

  final FundraisingAccount _account;
  final List<FundraisingPayoutMethod> _payoutMethods;

  @override
  Future<FundraisingAccount> fetchMyAccount() async => _account;

  @override
  Future<List<FundraisingPayoutMethod>> listMyPayoutMethods() async =>
      _payoutMethods;
}

class _InMemoryRecoveryService extends FundraisingDraftRecoveryService {
  _InMemoryRecoveryService(this.saved);

  FundraisingDraftRecovery? saved;

  @override
  Future<FundraisingDraftRecovery?> load() async => saved;

  @override
  Future<void> save(FundraisingDraftRecovery recovery) async {
    saved = recovery;
  }

  @override
  Future<void> clear() async {
    saved = null;
  }
}

class _FakePetRepository implements PetRepository {
  @override
  Future<List<PetEntity>> getAllPets() async => const <PetEntity>[];

  @override
  Future<int> createPet(PetEntity pet) => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAnimalTypes() =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getBreeds(int typeId) =>
      throw UnimplementedError();

  @override
  Future<void> followPet(int petId) => throw UnimplementedError();

  @override
  Future<PetEntity> getPublicPet(int petId) => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getPetPosts(int petId, {int? cursor}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getPetSocialStatus(int petId) =>
      throw UnimplementedError();

  @override
  Future<void> likePet(int petId) => throw UnimplementedError();

  @override
  Future<void> unfollowPet(int petId) => throw UnimplementedError();

  @override
  Future<void> unlikePet(int petId) => throw UnimplementedError();

  @override
  Future<void> updatePet(int petId, PetEntity pet) =>
      throw UnimplementedError();

  @override
  Future<void> updatePetPhoto(int petId, File file) =>
      throw UnimplementedError();

  @override
  Future<void> updatePetPublicProfile(int petId, Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<int> uploadPetPhoto(File file) => throw UnimplementedError();

  @override
  Future<void> uploadPetCoverPhoto(int petId, File file) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> createPetPost(
    int petId,
    Map<String, dynamic> payload,
  ) => throw UnimplementedError();
}

Future<UploadedMediaResult> _successfulUpload(
  MediaDraftItem item, {
  void Function(int sentBytes, int totalBytes)? onProgress,
  CancelToken? cancelToken,
}) async {
  onProgress?.call(100, 100);
  return UploadedMediaResult(
    id: item.id.hashCode.abs(),
    type: item.isVideo ? 'VIDEO' : (item.isDocument ? 'DOCUMENT' : 'IMAGE'),
    status: item.isVideo ? 'PROCESSING' : 'READY',
  );
}

final FundraisingAccount _verifiedAccount = FundraisingAccount(
  id: 1,
  status: 'VERIFIED',
  accountType: 'INDIVIDUAL',
  presentAddress: 'Dhaka',
  permanentAddress: 'Dhaka',
  occupation: 'Volunteer',
  divisionId: 30,
  districtId: 3026,
  upazilaId: 302601,
  unionId: null,
  areaId: 5001,
  dateOfBirth: DateTime(1995, 1, 1),
  nationalIdNumber: null,
  birthRegNumber: null,
  studentIdNumber: null,
  area: 'Dhanmondi',
  rescueSinceYear: null,
  orgName: null,
  orgDescription: null,
  orgWorkType: null,
  submittedAt: null,
  documents: <FundraisingAccountDocument>[
    FundraisingAccountDocument(id: 9, title: 'NID', mediaUrl: 'nid.pdf'),
  ],
  countryCode: 'BD',
  countryName: 'Bangladesh',
  stateName: 'Dhaka',
  cityName: 'Dhaka',
  addressLine: 'Road 12',
  latitude: null,
  longitude: null,
  formattedAddress: 'Dhaka, Bangladesh',
);

const List<FundraisingPayoutMethod> _activePayoutMethods =
    <FundraisingPayoutMethod>[
      FundraisingPayoutMethod(
        id: 10,
        catalogId: 1,
        label: 'Primary bKash',
        detailsJson: <String, dynamic>{'walletNumber': '01700000000'},
        maskedSummary: 'Wallet ending 0000',
        isDefault: true,
        isActive: true,
      ),
    ];
