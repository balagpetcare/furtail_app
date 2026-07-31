import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_create_screen.dart';
import 'package:furtail_app/features/location/presentation/providers/location_provider.dart';
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

/// Regression coverage for stale fundraising media leaking into a new
/// Create Fundraiser session: the media-session storage key is shared/fixed
/// (single local WIP-draft design), so it must be reconciled against
/// whether there is actually a draft to resume.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('a genuinely new fundraiser starts with an empty media list', (
    tester,
  ) async {
    _seedRestoredMedia();

    final repo = _ThrowingFundraisingRepository.withAccount(
      _completedAccount(status: 'VERIFIED'),
    );
    final controller = FundraisingCreateWizardController(
      repository: repo,
      recoveryService: _InMemoryRecoveryService(null),
    );
    final mediaController = _buildMediaController();

    await _pumpScreen(
      tester,
      repo: repo,
      controller: controller,
      mediaController: mediaController,
    );

    expect(mediaController.items, isEmpty);
  });

  testWidgets('a saved draft restores its own media', (tester) async {
    _seedRestoredMedia();

    final repo = _ThrowingFundraisingRepository.withAccount(
      _completedAccount(status: 'VERIFIED'),
    );
    final controller = FundraisingCreateWizardController(
      repository: repo,
      recoveryService: _InMemoryRecoveryService(
        FundraisingDraftRecovery.empty().copyWith(
          title: 'Help Tuni recover',
          story:
              'This is a sufficiently long fundraiser story that satisfies validation.',
          category: 'TREATMENT',
          beneficiaryName: 'Tuni',
          beneficiaryType: 'PET',
          mediaIds: const <int>[4242],
        ),
      ),
    );
    final mediaController = _buildMediaController();

    await _pumpScreen(
      tester,
      repo: repo,
      controller: controller,
      mediaController: mediaController,
    );

    expect(mediaController.items, hasLength(1));
    expect(mediaController.items.single.remoteMediaId, 4242);
  });

  testWidgets(
    'one READY media item still previews and submits correctly for a resumed draft',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'media_composer.$_draftStorageKey':
            MediaDraftItem.encodeList(const <MediaDraftItem>[
              MediaDraftItem(
                id: 'ready-photo',
                type: MediaDraftType.image,
                fileName: 'ready-photo.jpg',
                originalSizeBytes: 5,
                state: MediaDraftState.ready,
                remoteMediaId: 777,
              ),
            ]),
      });

      final repo = _ThrowingFundraisingRepository.withAccount(
        _completedAccount(status: 'VERIFIED'),
      );
      final controller = FundraisingCreateWizardController(
        repository: repo,
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty().copyWith(
            title: 'Help Tuni recover',
            story:
                'This is a sufficiently long fundraiser story that satisfies validation.',
            category: 'TREATMENT',
            beneficiaryName: 'Tuni',
            beneficiaryType: 'PET',
            mediaIds: const <int>[777],
          ),
        ),
      );
      final mediaController = _buildMediaController();

      await _pumpScreen(
        tester,
        repo: repo,
        controller: controller,
        mediaController: mediaController,
      );

      expect(mediaController.items, hasLength(1));
      expect(mediaController.allItemsReady, isTrue);
      expect(mediaController.mediaValidation.hasFailedItems, isFalse);
      expect(mediaController.mediaValidation.hasPendingItems, isFalse);
    },
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FundraisingRepository repo,
  required FundraisingCreateWizardController controller,
  required MediaComposerController mediaController,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        fundraisingMyAccountProvider.overrideWith(
          (ref) async => repo.fetchMyAccount(),
        ),
        locationDivisionsProvider.overrideWith(
          (ref) async => const <BdDivision>[
            BdDivision(id: 30, code: 'DIV-30', nameEn: 'Dhaka'),
          ],
        ),
        getPetsUsecaseProvider.overrideWithValue(
          GetPetsUsecase(_FakePetRepository()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: Text('behind-the-wizard'))),
      ),
    ),
  );
  await tester.pump();

  unawaited(
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => FundraisingCreateScreen(
          repository: repo,
          controller: controller,
          mediaController: mediaController,
        ),
      ),
    ),
  );
  for (var i = 0; i < 60; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    final hasVisibleState =
        find.text('Step 1 of 6').evaluate().isNotEmpty ||
        find.text('Step 2 of 6').evaluate().isNotEmpty ||
        find.text('Step 3 of 6').evaluate().isNotEmpty ||
        find.text('Step 4 of 6').evaluate().isNotEmpty ||
        find.text('Step 5 of 6').evaluate().isNotEmpty ||
        find.text('Step 6 of 6').evaluate().isNotEmpty ||
        find.text('Complete your fundraising profile').evaluate().isNotEmpty;
    if (hasVisibleState) break;
  }
  await tester.pump();
}

const _draftStorageKey = 'fundraising-media-session-test';

void _seedRestoredMedia() {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'media_composer.$_draftStorageKey':
        MediaDraftItem.encodeList(const <MediaDraftItem>[
          MediaDraftItem(
            id: 'restored-photo',
            type: MediaDraftType.image,
            fileName: 'restored-photo.jpg',
            originalSizeBytes: 5,
            state: MediaDraftState.ready,
            remoteMediaId: 4242,
          ),
        ]),
  });
}

MediaComposerController _buildMediaController() {
  return MediaComposerController(
    policy: MediaComposerPolicy.fundraising,
    draftStorageKey: _draftStorageKey,
    uploadMedia: _successfulUpload,
  );
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

class _ThrowingFundraisingRepository extends FundraisingRepository {
  _ThrowingFundraisingRepository.withAccount(this.account)
    : error = null,
      super(ApiClient(dio: Dio()));

  final Object? error;
  final FundraisingAccount? account;

  @override
  Future<FundraisingAccount?> fetchMyAccount() async {
    if (error != null) throw error!;
    return account;
  }
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

FundraisingAccount _completedAccount({required String status}) {
  return FundraisingAccount(
    id: 1,
    status: status,
    accountType: 'INDIVIDUAL',
    fullName: 'Tuni Rahman',
    presentAddress: 'Dhaka',
    permanentAddress: 'Dhaka',
    occupation: 'Volunteer',
    divisionId: 30,
    districtId: 3026,
    upazilaId: 302601,
    unionId: 5001,
    areaId: null,
    dateOfBirth: DateTime(1995, 1, 1),
    primaryDocumentType: 'NID',
    nationalIdNumber: '1234567890',
    birthRegNumber: null,
    studentIdNumber: null,
    area: 'Dhanmondi',
    rescueSinceYear: null,
    orgName: null,
    orgDescription: null,
    orgWorkType: null,
    submittedAt: null,
    documents: const <FundraisingAccountDocument>[
      FundraisingAccountDocument(
        id: 9,
        title: 'NID',
        documentType: 'PRIMARY',
        mediaUrl: 'nid.pdf',
      ),
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
}

class _FakePetRepository implements PetRepository {
  @override
  Future<List<PetEntity>> getAllPets() async => const <PetEntity>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
