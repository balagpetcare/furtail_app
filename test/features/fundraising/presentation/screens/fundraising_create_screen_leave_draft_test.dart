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

/// Regression coverage for the false "Leave fundraiser draft?" confirmation.
/// Backing out of a preflight that never opened the wizard is not abandoning
/// work, so it must exit directly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('failed preflight then Back exits without the leave dialog', (
    tester,
  ) async {
    // Media persisted by an earlier session. `_initializeAsync` restores it
    // before the account fetch, which is what used to make an untouched,
    // failed preflight look like an abandoned draft.
    _seedRestoredMedia();

    final repo = _ThrowingFundraisingRepository(
      ApiClientException(
        message: 'incomplete',
        statusCode: 409,
        code: 'FUNDRAISING_ACCOUNT_INCOMPLETE',
        responseData: const {
          'details': {
            'missingRequirements': ['presentAddress'],
          },
        },
      ),
    );
    final controller = FundraisingCreateWizardController(
      repository: repo,
      recoveryService: _InMemoryRecoveryService(
        FundraisingDraftRecovery.empty(),
      ),
    );

    await _pumpScreen(tester, repo: repo, controller: controller);

    // The preflight failed, so the wizard form never opened.
    expect(find.text('Complete your fundraising profile'), findsOneWidget);
    expect(controller.initialized, isFalse);

    final context = tester.element(find.byType(FundraisingCreateScreen));
    unawaited(Navigator.of(context).maybePop());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Leave fundraiser draft?'), findsNothing);
  });

  testWidgets('untouched initialized wizard exits without the leave dialog', (
    tester,
  ) async {
    final repo = _ThrowingFundraisingRepository.withAccount(
      _completedAccount(status: 'VERIFIED'),
    );
    final controller = FundraisingCreateWizardController(
      repository: repo,
      recoveryService: _InMemoryRecoveryService(
        FundraisingDraftRecovery.empty(),
      ),
    );

    await _pumpScreen(tester, repo: repo, controller: controller);

    // Wizard opened, but the user changed nothing.
    expect(find.text('Step 1 of 6'), findsOneWidget);

    unawaited(tester.binding.handlePopRoute());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Leave fundraiser draft?'), findsNothing);
    expect(find.byType(FundraisingCreateScreen), findsNothing);
  });

  testWidgets('a recovered draft still shows the leave confirmation', (
    tester,
  ) async {
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
        ),
      ),
    );

    await _pumpScreen(tester, repo: repo, controller: controller);

    unawaited(tester.binding.handlePopRoute());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Real recovered work — the user must get the chance to save it.
    expect(find.text('Leave fundraiser draft?'), findsOneWidget);
    expect(find.byType(FundraisingCreateScreen), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FundraisingRepository repo,
  required FundraisingCreateWizardController controller,
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
        // A real route below the wizard so Back has somewhere to pop to.
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
          mediaController: _buildMediaController(),
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

const _draftStorageKey = 'fundraising-leave-draft-test';

/// Persists one already-uploaded media item so `MediaComposerController.restore()`
/// brings it back, reproducing the state that triggered the false dialog.
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
  _ThrowingFundraisingRepository(this.error)
    : account = null,
      super(ApiClient(dio: Dio()));

  _ThrowingFundraisingRepository.withAccount(this.account)
    : error = null,
      super(ApiClient(dio: Dio()));

  final Object? error;
  final FundraisingAccount? account;
  int fetchMyAccountCalls = 0;

  @override
  Future<FundraisingAccount?> fetchMyAccount() async {
    fetchMyAccountCalls += 1;
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
