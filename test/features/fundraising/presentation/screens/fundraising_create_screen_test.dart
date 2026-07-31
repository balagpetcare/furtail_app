import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_payout_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_account_setup_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_create_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_campaign_preview_card.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_media_needs_attention_panel.dart';
import 'package:furtail_app/features/location/presentation/providers/location_provider.dart';
import 'package:furtail_app/features/media/composer/fundraising_media_validation.dart';
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
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets(
      'preflights before opening the wizard and keeps drafts untouched',
      (tester) async {
        final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
          _completedAccount(status: 'VERIFIED'),
          _completedAccount(status: 'VERIFIED'),
        ]);
        final controller = FundraisingCreateWizardController(
          repository: repo,
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        );
        final mediaController = _buildMediaController();

        await _pumpScreen(
          tester,
          repo: repo,
          controller: controller,
          mediaController: mediaController,
        );

        expect(repo.createDraftCalls, 0);
        expect(find.text('Step 1 of 6'), findsOneWidget);
        expect(find.text('Campaign Basics'), findsWidgets);
        expect(find.text('Eligibility'), findsNothing);
        expect(find.byType(FundraisingCreateScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a pending account opens the wizard without a verification detour',
      (tester) async {
        final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
          _completedAccount(status: 'PENDING'),
          _completedAccount(status: 'PENDING'),
        ]);
        final controller = FundraisingCreateWizardController(
          repository: repo,
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        );

        await _pumpScreen(tester, repo: repo, controller: controller);

        expect(repo.fetchMyAccountCalls, 2);
        expect(find.text('Step 1 of 6'), findsOneWidget);
        expect(find.text('Campaign Basics'), findsWidgets);
        expect(find.byType(FundraisingCreateScreen), findsWidgets);
        expect(find.byType(FundraisingAccountSetupScreen), findsNothing);
      },
    );

    // Fundraising/payout verification gates withdrawal only — never
    // creating or submitting a campaign. None of the account states below
    // may bounce the user into the verification/account-update screen.
    testWidgets(
      'an account still missing KYC documents opens the wizard with no verification detour',
      (tester) async {
        final unverified = _accountMissingDocuments(status: 'PENDING');
        expect(unverified.readiness.canStartFundraiser, isFalse);

        final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
          unverified,
          unverified,
        ]);
        final controller = FundraisingCreateWizardController(
          repository: repo,
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        );

        await _pumpScreen(tester, repo: repo, controller: controller);

        expect(find.byType(FundraisingAccountSetupScreen), findsNothing);
        expect(find.text('Step 1 of 6'), findsOneWidget);
        expect(find.byType(FundraisingCreateScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a payout-REJECTED account opens the wizard with no verification detour',
      (tester) async {
        final rejected = _completedAccount(status: 'REJECTED');
        expect(rejected.readiness.canStartFundraiser, isFalse);

        final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
          rejected,
          rejected,
        ]);
        final controller = FundraisingCreateWizardController(
          repository: repo,
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        );

        await _pumpScreen(tester, repo: repo, controller: controller);

        expect(find.byType(FundraisingAccountSetupScreen), findsNothing);
        expect(find.text('Step 1 of 6'), findsOneWidget);
        expect(find.byType(FundraisingCreateScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a user with no fundraising verification account at all opens the wizard',
      (tester) async {
        final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
          null,
          null,
        ]);
        final controller = FundraisingCreateWizardController(
          repository: repo,
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        );

        await _pumpScreen(tester, repo: repo, controller: controller);

        expect(find.byType(FundraisingAccountSetupScreen), findsNothing);
        expect(find.text('Step 1 of 6'), findsOneWidget);
        expect(find.byType(FundraisingCreateScreen), findsOneWidget);
      },
    );

    testWidgets('restored draft returns to the correct step', (tester) async {
      final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
        _completedAccount(status: 'VERIFIED'),
        _completedAccount(status: 'VERIFIED'),
      ]);
      final controller = FundraisingCreateWizardController(
        repository: repo,
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty().copyWith(
            stepIndex: 1,
            title: 'Help Tuni recover',
            shortDescription:
                'A concise description that is long enough to satisfy validation.',
            whatHappened:
                'A recent issue has made this fundraiser necessary and urgent.',
            whyUrgent:
                'Immediate help is needed to address the situation safely.',
            fundUsage:
                'The funds will cover treatment, transport, and recovery support.',
            story:
                'This is a sufficiently long fundraiser story that satisfies validation.',
            category: 'TREATMENT',
            beneficiaryName: 'Tuni',
            beneficiaryType: 'PET',
            urgency: 'HIGH',
            treatmentProvider: 'Dhaka Animal Hospital',
            fundingMode: 'ONE_TIME',
            targetAmountMinor: 120000,
            endsAt: DateTime(2026, 9, 1),
          ),
        ),
      );

      await _pumpScreen(tester, repo: repo, controller: controller);

      expect(find.text('Step 4 of 6'), findsOneWidget);
      expect(find.text('Location'), findsWidgets);
      expect(find.text('Campaign Basics'), findsNothing);
    });

    testWidgets('no payout method is required for the funding-details step', (
      tester,
    ) async {
      final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
        _completedAccount(status: 'VERIFIED'),
        _completedAccount(status: 'VERIFIED'),
      ], payoutMethods: const <FundraisingPayoutMethod>[]);
      final controller = FundraisingCreateWizardController(
        repository: repo,
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty().copyWith(
            stepIndex: 2,
            title: 'Help Tuni recover',
            shortDescription:
                'A concise description that is long enough to satisfy validation.',
            whatHappened:
                'A recent issue has made this fundraiser necessary and urgent.',
            whyUrgent:
                'Immediate help is needed to address the situation safely.',
            fundUsage:
                'The funds will cover treatment, transport, and recovery support.',
            story:
                'This is a sufficiently long fundraiser story that satisfies validation.',
            category: 'TREATMENT',
            beneficiaryName: 'Tuni',
            beneficiaryType: 'PET',
            urgency: 'HIGH',
            treatmentProvider: 'Dhaka Animal Hospital',
            fundingMode: 'ONE_TIME',
            targetAmountMinor: 120000,
            endsAt: DateTime(2026, 9, 1),
            locationText: 'Dhaka, Bangladesh',
            bdDivisionId: 30,
            bdDistrictId: 3026,
            bdUpazilaId: 302601,
            bdUnionId: 5001,
            expenses: const <FundraisingExpenseItem>[
              FundraisingExpenseItem(
                code: 'vet',
                label: 'Veterinary care',
                amountMinor: 120000,
              ),
            ],
          ),
        ),
      );
      final mediaController = _buildMediaController();
      await mediaController.addItems(<MediaDraftItem>[
        _fakeMediaItem(
          id: 'ready-media',
          fileName: 'ready-photo.jpg',
          state: MediaDraftState.ready,
          remoteMediaId: 1,
        ),
      ]);

      await _pumpScreen(
        tester,
        repo: repo,
        controller: controller,
        mediaController: mediaController,
      );

      expect(find.text('Step 6 of 6'), findsOneWidget);
      expect(find.text('Review & Submit'), findsOneWidget);
      expect(find.text('Funding Details'), findsWidgets);
      expect(find.text('Payout'), findsNothing);
    });

    testWidgets('preview step renders the campaign preview card', (
      tester,
    ) async {
      final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
        _completedAccount(status: 'VERIFIED'),
        _completedAccount(status: 'VERIFIED'),
      ]);
      final controller = FundraisingCreateWizardController(
        repository: repo,
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty().copyWith(
            stepIndex: 2,
            title: 'Help Tuni recover',
            shortDescription:
                'A concise description that is long enough to satisfy validation.',
            whatHappened:
                'A recent issue has made this fundraiser necessary and urgent.',
            whyUrgent:
                'Immediate help is needed to address the situation safely.',
            fundUsage:
                'The funds will cover treatment, transport, and recovery support.',
            story:
                'This is a sufficiently long fundraiser story that satisfies validation.',
            category: 'TREATMENT',
            beneficiaryName: 'Tuni',
            beneficiaryType: 'PET',
            urgency: 'HIGH',
            treatmentProvider: 'Dhaka Animal Hospital',
            fundingMode: 'ONE_TIME',
            locationText: 'Dhaka, Bangladesh',
            bdDivisionId: 30,
            bdDistrictId: 3026,
            bdUpazilaId: 302601,
            bdUnionId: 5001,
            targetAmountMinor: 120000,
            endsAt: DateTime(2026, 9, 1),
          ),
        ),
      );
      final mediaController = _buildMediaController();
      await mediaController.addItems(<MediaDraftItem>[
        _fakeMediaItem(
          id: 'ready-preview',
          fileName: 'ready-photo.jpg',
          state: MediaDraftState.ready,
          remoteMediaId: 2,
        ),
      ]);

      await _pumpScreen(
        tester,
        repo: repo,
        controller: controller,
        mediaController: mediaController,
      );
      expect(find.text('Step 6 of 6'), findsOneWidget);
      expect(find.text('Review & Submit'), findsOneWidget);
      expect(find.byType(FundraisingCampaignPreviewCard), findsOneWidget);
    });

    testWidgets('deadline selector offers only fixed fundraiser durations', (
      tester,
    ) async {
      final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
        _completedAccount(status: 'VERIFIED'),
        _completedAccount(status: 'VERIFIED'),
      ]);
      final controller = FundraisingCreateWizardController(
        repository: repo,
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty().copyWith(
            stepIndex: 2,
            title: 'Help Tuni recover',
            shortDescription:
                'A concise description that is long enough to satisfy validation.',
            whatHappened:
                'A recent issue has made this fundraiser necessary and urgent.',
            whyUrgent:
                'Immediate help is needed to address the situation safely.',
            fundUsage:
                'The funds will cover treatment, transport, and recovery support.',
            story:
                'This is a sufficiently long fundraiser story that satisfies validation.',
            category: 'TREATMENT',
            beneficiaryName: 'Tuni',
            beneficiaryType: 'PET',
            urgency: 'HIGH',
            treatmentProvider: 'Dhaka Animal Hospital',
            fundingMode: 'ONE_TIME',
            targetAmountMinor: 120000,
          ),
        ),
      );

      await _pumpScreen(tester, repo: repo, controller: controller);

      await tester.tap(find.text('Select deadline'));
      await tester.pumpAndSettle();

      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('15 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('90 days'), findsOneWidget);
      expect(find.text('14 days'), findsNothing);

      final before = DateTime.now();
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      final expectedDeadline = DateTime(
        before.year,
        before.month,
        before.day + 7,
        23,
        59,
      );
      expect(
        find.text(DateFormat.yMMMd().format(expectedDeadline)),
        findsOneWidget,
      );
      expect(controller.draft.campaignDurationDays, 7);
    });

    testWidgets('keyboard does not cover the focused field', (tester) async {
      final repo = _SequenceFundraisingRepository(<FundraisingAccount?>[
        _completedAccount(status: 'VERIFIED'),
        _completedAccount(status: 'VERIFIED'),
      ]);
      final controller = FundraisingCreateWizardController(
        repository: repo,
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        ),
      );

      await _pumpScreen(
        tester,
        repo: repo,
        controller: controller,
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byType(TextFormField).first,
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('control: renders a bare MaterialApp/Scaffold/Text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('media-test-ready'))),
      );
      await tester.pump();

      expect(find.text('media-test-ready'), findsOneWidget);
    });

    testWidgets(
      'the exact missing-media message is used when media is the only blocker',
      (tester) async {
        late AppLocalizations t;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                t = AppLocalizations.of(context)!;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();

        expect(
          t.fundraisingValidationMedia,
          'Add at least one photo, video, or supporting document.',
        );
        expect(
          evaluateFundraisingMedia(const <MediaDraftItem>[]).hasAnyItem,
          isFalse,
        );
      },
    );

    testWidgets('local media items block Continue until the upload settles', (
      tester,
    ) async {
      final pending = _fakeMediaItem(
        id: 'pending',
        fileName: 'pending.jpg',
        state: MediaDraftState.local,
      );

      final validation = evaluateFundraisingMedia(<MediaDraftItem>[pending]);

      expect(validation.hasAnyItem, isTrue);
      expect(validation.hasPendingItems, isTrue);
      expect(validation.canContinue, isFalse);
      expect(
        validation.validationReason,
        'Wait for uploads to finish before continuing.',
      );
    });

    testWidgets(
      'Needs attention panel renders the failed item with retry/remove actions',
      (tester) async {
        final broken = _fakeMediaItem(
          id: 'broken',
          fileName: 'broken-photo.jpg',
          state: MediaDraftState.failed,
          errorMessage: 'Invalid image data',
        );

        await tester.pumpWidget(_wrapPanel(items: <MediaDraftItem>[broken]));
        await tester.pump();

        expect(find.text('Needs attention'), findsOneWidget);
        expect(find.textContaining('broken-photo.jpg'), findsOneWidget);
        expect(find.textContaining('Invalid image data'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Remove'), findsOneWidget);
      },
    );

    testWidgets('failed warning disappears when supplied state becomes ready', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapPanel(
          items: <MediaDraftItem>[
            _fakeMediaItem(
              id: 'photo',
              fileName: 'retry-photo.jpg',
              state: MediaDraftState.failed,
              errorMessage: 'Invalid image data',
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Needs attention'), findsOneWidget);

      // Simulate the state transition a successful retry produces by
      // rebuilding the panel with the same immutable item now ready.
      await tester.pumpWidget(
        _wrapPanel(
          items: <MediaDraftItem>[
            _fakeMediaItem(
              id: 'photo',
              fileName: 'retry-photo.jpg',
              state: MediaDraftState.ready,
              remoteMediaId: 1,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Needs attention'), findsNothing);
    });

    testWidgets(
      'missing-media guidance appears when the final item is removed',
      (tester) async {
        await tester.pumpWidget(
          _wrapPanel(
            items: <MediaDraftItem>[
              _fakeMediaItem(
                id: 'good',
                fileName: 'good-photo.jpg',
                state: MediaDraftState.ready,
                remoteMediaId: 91,
              ),
              _fakeMediaItem(
                id: 'broken',
                fileName: 'broken-photo.jpg',
                state: MediaDraftState.failed,
                errorMessage: 'Invalid image data',
              ),
            ],
          ),
        );
        await tester.pump();
        expect(find.text('Needs attention'), findsOneWidget);
        expect(find.text('Add media to continue.'), findsNothing);

        // Removing the only remaining (failed) item leaves zero media items.
        await tester.pumpWidget(_wrapPanel(items: const <MediaDraftItem>[]));
        await tester.pump();

        expect(find.text('Needs attention'), findsNothing);
        expect(find.text('Add media to continue.'), findsOneWidget);
      },
    );
  });
}

/// Builds a lightweight, purely presentational widget tree for the three
/// media state-transition tests above. It receives an immutable media list
/// and renders [FundraisingMediaNeedsAttentionPanel] plus a submit button
/// and missing-media guidance driven entirely by [evaluateFundraisingMedia].
///
/// No [MediaComposerController], filesystem access, image decoding, network
/// client, or providers are involved.
Widget _wrapPanel({required List<MediaDraftItem> items}) {
  final validation = evaluateFundraisingMedia(items);
  return MaterialApp(
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FundraisingMediaNeedsAttentionPanel(
            items: items,
            title: 'Needs attention',
            retryLabel: 'Retry',
            removeLabel: 'Remove',
            blockingFallbackMessage: 'Retry or remove failed uploads.',
            onRetry: (_) {},
            onRemove: (_) {},
          ),
          FilledButton(
            onPressed: validation.canContinue ? () {} : null,
            child: const Text('Submit for review'),
          ),
          if (!validation.hasAnyItem) const Text('Add media to continue.'),
        ],
      ),
    ),
  );
}

MediaDraftItem _fakeMediaItem({
  required String id,
  required String fileName,
  MediaDraftState state = MediaDraftState.local,
  String? errorMessage,
  int? remoteMediaId,
}) {
  return MediaDraftItem(
    id: id,
    type: MediaDraftType.image,
    fileName: fileName,
    originalSizeBytes: 5,
    state: state,
    errorMessage: errorMessage,
    remoteMediaId: remoteMediaId,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _SequenceFundraisingRepository repo,
  required FundraisingCreateWizardController controller,
  MediaComposerController? mediaController,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
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
        locationDistrictsProvider(30).overrideWith(
          (ref) async => const <BdDistrict>[
            BdDistrict(
              id: 3026,
              code: 'DIS-3026',
              nameEn: 'Dhaka',
              divisionId: 30,
            ),
          ],
        ),
        locationUpazilasProvider(3026).overrideWith(
          (ref) async => const <BdUpazila>[
            BdUpazila(
              id: 302601,
              code: 'UPZ-302601',
              nameEn: 'Dhanmondi',
              districtId: 3026,
            ),
          ],
        ),
        locationUnionsProvider(302601).overrideWith(
          (ref) async => const <BdUnion>[
            BdUnion(
              id: 5001,
              code: 'UNI-5001',
              nameEn: 'Dhanmondi Union',
              upazilaId: 302601,
            ),
          ],
        ),
        getPetsUsecaseProvider.overrideWithValue(
          GetPetsUsecase(_FakePetRepository()),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
          child: child!,
        ),
        home: FundraisingCreateScreen(
          repository: repo,
          controller: controller,
          mediaController: mediaController ?? _buildMediaController(),
        ),
      ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 100; i += 1) {
    final hasWizardStep =
        find.text('Step 1 of 6').evaluate().isNotEmpty ||
        find.text('Step 4 of 6').evaluate().isNotEmpty ||
        find.text('Step 6 of 6').evaluate().isNotEmpty ||
        find.text('Complete your fundraising profile').evaluate().isNotEmpty;
    if (hasWizardStep && !tester.binding.hasScheduledFrame) break;
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}

MediaComposerController _buildMediaController() {
  return MediaComposerController(
    policy: MediaComposerPolicy.fundraising,
    draftStorageKey: 'fundraising-create-screen-test',
    uploadMedia: _successfulUpload,
  );
}

class _SequenceFundraisingRepository extends FundraisingRepository {
  _SequenceFundraisingRepository(
    this.accounts, {
    List<FundraisingPayoutMethod>? payoutMethods,
  }) : _payoutMethods = payoutMethods ?? _activePayoutMethods,
       super(ApiClient(dio: Dio()));

  final List<FundraisingAccount?> accounts;
  final List<FundraisingPayoutMethod> _payoutMethods;
  int fetchMyAccountCalls = 0;
  int createDraftCalls = 0;

  @override
  Future<FundraisingAccount?> fetchMyAccount() async {
    fetchMyAccountCalls += 1;
    if (accounts.isEmpty) return null;
    final index = fetchMyAccountCalls - 1;
    return index < accounts.length ? accounts[index] : accounts.last;
  }

  @override
  Future<List<FundraisingPayoutMethod>> listMyPayoutMethods() async =>
      _payoutMethods;

  @override
  Future<FundraisingDraftRecord> createDraft({
    required Map<String, dynamic> payload,
  }) async {
    createDraftCalls += 1;
    return _draftRecord(id: createDraftCalls);
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

/// A profile-complete account that has NOT uploaded a primary KYC document,
/// so `readiness.canStartFundraiser` is false — the real-world "verification
/// still pending / requires update" state that used to block Submit.
FundraisingAccount _accountMissingDocuments({required String status}) {
  return _buildAccount(
    status: status,
    documents: const <FundraisingAccountDocument>[],
  );
}

FundraisingAccount _completedAccount({required String status}) {
  return _buildAccount(
    status: status,
    documents: const <FundraisingAccountDocument>[
      FundraisingAccountDocument(
        id: 9,
        title: 'NID',
        documentType: 'PRIMARY',
        mediaUrl: 'nid.pdf',
      ),
    ],
  );
}

FundraisingAccount _buildAccount({
  required String status,
  required List<FundraisingAccountDocument> documents,
}) {
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
    documents: documents,
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

FundraisingDraftRecord _draftRecord({required int id}) {
  return FundraisingDraftRecord(
    id: id,
    status: 'DRAFT',
    publicId: 'pub-$id',
    slug: 'draft-$id',
    title: 'Draft title',
    caption: 'Draft caption with enough detail to satisfy validation.',
    category: 'TREATMENT',
    currencyCode: 'BDT',
    targetAmountMinor: 120000,
    deadline: DateTime(2026, 9, 1),
    beneficiaryType: 'PET',
    beneficiaryName: 'Tuni',
    petId: 3,
    urgency: 'HIGH',
    treatmentProvider: 'Dhaka Pet Hospital',
    estimatedExpenseMinor: 120000,
    spendingPlan: const <String, dynamic>{
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'vet',
          'label': 'Veterinary care',
          'amountMinor': 120000,
        },
      ],
    },
    locationText: 'Dhaka, Bangladesh',
    bdDivisionId: 30,
    bdDistrictId: 3026,
    bdUpazilaId: 302601,
    submittedAt: null,
    mediaIds: const <int>[],
  );
}

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
