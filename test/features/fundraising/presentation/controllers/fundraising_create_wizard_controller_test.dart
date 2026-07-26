import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_payout_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart';
import 'package:furtail_app/features/media/composer/fundraising_media_validation.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FundraisingCreateWizardController', () {
    test('readiness blocks missing account, profile, and documents', () {
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(),
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        ),
      );

      expect(controller.canStartFundraiser, isFalse);
      expect(controller.readiness.accountExists, isFalse);
      expect(controller.readiness.requiredProfileComplete, isFalse);
      expect(controller.readiness.requiredDocumentsUploaded, isFalse);
      expect(
        controller.missingVerificationActions,
        contains('complete_profile'),
      );
      expect(
        controller.missingVerificationActions,
        contains('upload_documents'),
      );
    });

    test(
      'pending review stays eligible once profile and documents are complete',
      () {
        final controller = FundraisingCreateWizardController(
          repository: _FakeFundraisingRepository(
            account: _completedAccount(status: 'PENDING'),
          ),
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        )..seedAccount(_completedAccount(status: 'PENDING'));

        expect(controller.canStartFundraiser, isTrue);
        expect(controller.readiness.isPendingReview, isTrue);
      },
    );

    test('verified accounts can start a fundraiser', () {
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(
          account: _completedAccount(status: 'VERIFIED'),
        ),
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        ),
      )..seedAccount(_completedAccount(status: 'VERIFIED'));

      expect(controller.canStartFundraiser, isTrue);
      expect(controller.readiness.status, 'VERIFIED');
    });

    // SUSPENDED and BLOCKED are no longer valid Prisma enum values; they
    // are normalized to PENDING. See Step 2: account status validation.
    // Therefore, no test for these statuses exists.

    test('rejected accounts require correction guidance', () {
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(
          account: _completedAccount(status: 'REJECTED'),
        ),
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        ),
      )..seedAccount(_completedAccount(status: 'REJECTED'));

      expect(controller.canStartFundraiser, isFalse);
      expect(controller.readiness.isRejected, isTrue);
      expect(controller.readiness.safeRejectionReason, isNotNull);
      expect(
        controller.missingVerificationActions,
        contains('resolve_rejection'),
      );
    });

    test(
      'initialize does not create a server draft during preflight',
      () async {
        final repository = _FakeFundraisingRepository(
          account: _completedAccount(status: 'VERIFIED'),
        );
        final controller = FundraisingCreateWizardController(
          repository: repository,
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        )..seedAccount(_completedAccount(status: 'VERIFIED'));

        await controller.initialize();

        expect(repository.createDraftCalls, 0);
      },
    );

    test(
      'saves local recovery before a draft save failure and clears it on success',
      () async {
        final recoveryService = _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        );
        final repository = _FakeFundraisingRepository(createFailsFirst: true);
        final controller = FundraisingCreateWizardController(
          repository: repository,
          recoveryService: recoveryService,
        );

        await controller.updateDraft(
          (current) => current.copyWith(
            title: 'Help Tuni recover',
            story:
                'This is a sufficiently long fundraiser story that satisfies validation.',
            category: 'TREATMENT',
            beneficiaryName: 'Tuni',
            targetAmountMinor: 120000,
            deadline: DateTime(2026, 9, 1),
            divisionName: 'Dhaka',
            districtName: 'Dhaka',
            upazilaName: 'Dhanmondi',
            areaName: 'Dhanmondi',
            customLocationNote: 'Dhaka, Bangladesh',
            locationText: 'Dhanmondi, Dhaka, Bangladesh',
          ),
          autosave: false,
        );

        await controller.saveDraftNow();

        expect(controller.draftFailure, isNotNull);
        expect(recoveryService.saved, isNotNull);
        expect(recoveryService.saved!.title, 'Help Tuni recover');
        expect(repository.createDraftCalls, 1);

        repository.createFailsFirst = false;
        await controller.saveDraftNow();

        expect(controller.draftFailure, isNull);
        expect(controller.draft.remoteDraftId, isNotNull);
        expect(repository.createDraftCalls, 2);
      },
    );

    test('ONE_TIME requires target and end date', () async {
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(
          account: _completedAccount(status: 'VERIFIED'),
        ),
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        ),
      )..seedAccount(_completedAccount(status: 'VERIFIED'));

      await controller.updateDraft(
        (current) => current.copyWith(
          category: 'TREATMENT',
          beneficiaryType: 'PET',
          beneficiaryName: 'Tuni',
          title: 'Help Tuni recover',
          story:
              'This is a sufficiently long fundraiser story that satisfies validation.',
          fundingMode: 'ONE_TIME',
          locationText: 'Dhaka, Bangladesh',
          clearTargetAmountMinor: true,
          clearEndsAt: true,
          clearDeadline: true,
        ),
        autosave: false,
      );

      expect(
        controller.validationCodesForStep(FundraisingWizardStep.fundraiserType),
        containsAll(<String>['target_amount_required', 'deadline_required']),
      );
    });

    test('ONGOING permits a null end date', () async {
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(
          account: _completedAccount(status: 'VERIFIED'),
        ),
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        ),
      )..seedAccount(_completedAccount(status: 'VERIFIED'));

      await controller.updateDraft(
        (current) => current.copyWith(
          category: 'SHELTER',
          beneficiaryType: 'ORGANIZATION',
          beneficiaryName: 'Shelter',
          title: 'Help a shelter stay open',
          story:
              'This is a sufficiently long fundraiser story that satisfies validation.',
          fundingMode: 'ONGOING',
          locationText: 'Dhaka, Bangladesh',
          monthlyGoalMinor: 50000,
        ),
        autosave: false,
      );

      expect(
        controller.validationCodesForStep(FundraisingWizardStep.fundraiserType),
        isNot(contains('deadline_required')),
      );
    });

    test('campaign submission does not require a payout method', () async {
      final repository = _FakeFundraisingRepository(
        account: _completedAccount(status: 'VERIFIED'),
        payoutMethods: const <FundraisingPayoutMethod>[],
      );
      final controller = FundraisingCreateWizardController(
        repository: repository,
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        ),
      )..seedAccount(_completedAccount(status: 'VERIFIED'));

      await controller.initialize();
      await controller.updateDraft(
        (current) => current.copyWith(
          category: 'TREATMENT',
          beneficiaryType: 'PET',
          beneficiaryName: 'Tuni',
          title: 'Help Tuni recover',
          story:
              'This is a sufficiently long fundraiser story that satisfies validation.',
          fundingMode: 'ONE_TIME',
          targetAmountMinor: 120000,
          endsAt: DateTime(2026, 9, 1),
          locationText: 'Dhaka, Bangladesh',
          customLocationNote: 'Dhaka, Bangladesh',
        ),
        autosave: false,
      );

      await controller.saveDraftNow();

      expect(repository.createDraftCalls, 1);
    });

    test(
      'pending verification is never reported as a location-step blocker',
      () {
        final controller = FundraisingCreateWizardController(
          repository: _FakeFundraisingRepository(
            account: _completedAccount(status: 'PENDING'),
          ),
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        )..seedAccount(_completedAccount(status: 'PENDING'));

        final codes = controller.validationCodesForStep(
          FundraisingWizardStep.location,
          mediaValidation: const FundraisingMediaValidationResult(
            hasAnyItem: true,
            hasFailedItems: false,
            hasPendingItems: false,
            canContinue: true,
            failedItemIds: <String>[],
            validationReason: null,
          ),
        );

        // A PENDING (not yet VERIFIED) account with ready media never
        // contributes a verification- or payout-related blocker — those
        // codes don't exist in this wizard at all.
        expect(codes, isNot(contains('media_required')));
        expect(codes, isNot(contains('media_blocking')));
        expect(
          codes.any(
            (code) => code.contains('verif') || code.contains('payout'),
          ),
          isFalse,
        );
      },
    );

    test('zero media items produce the exact missing-media blocker code', () {
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(
          account: _completedAccount(status: 'VERIFIED'),
        ),
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty(),
        ),
      )..seedAccount(_completedAccount(status: 'VERIFIED'));

      final codes = controller.validationCodesForStep(
        FundraisingWizardStep.location,
        mediaValidation: const FundraisingMediaValidationResult(
          hasAnyItem: false,
          hasFailedItems: false,
          hasPendingItems: false,
          canContinue: false,
          failedItemIds: <String>[],
          validationReason: 'Add at least one photo, video, or document.',
        ),
      );

      expect(codes, contains('media_required'));
      expect(codes, isNot(contains('media_blocking')));
    });

    test(
      'submitForReview submits once and returns a PENDING_REVIEW record',
      () async {
        final repository = _FakeFundraisingRepository(
          account: _completedAccount(status: 'PENDING'),
        );
        final controller = FundraisingCreateWizardController(
          repository: repository,
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        )..seedAccount(_completedAccount(status: 'PENDING'));

        await controller.updateDraft(
          (current) => current.copyWith(
            category: 'TREATMENT',
            beneficiaryType: 'PET',
            beneficiaryName: 'Tuni',
            title: 'Help Tuni recover',
            story:
                'This is a sufficiently long fundraiser story that satisfies validation.',
            fundingMode: 'ONE_TIME',
            targetAmountMinor: 120000,
            endsAt: DateTime(2026, 9, 1),
            customLocationNote: 'Dhaka, Bangladesh',
            locationText: 'Dhaka, Bangladesh',
          ),
          autosave: false,
        );

        final result = await controller.submitForReview();

        expect(result, isNotNull);
        expect(result!.status.toUpperCase(), 'PENDING_REVIEW');
        expect(repository.submitDraftCalls, 1);
        expect(repository.createDraftCalls, 1);
      },
    );

    test(
      'a resolved submission failure clears once the retry succeeds',
      () async {
        final repository = _FakeFundraisingRepository(
          account: _completedAccount(status: 'PENDING'),
          submitFailsFirst: true,
        );
        final controller = FundraisingCreateWizardController(
          repository: repository,
          recoveryService: _InMemoryRecoveryService(
            FundraisingDraftRecovery.empty(),
          ),
        )..seedAccount(_completedAccount(status: 'PENDING'));

        await controller.updateDraft(
          (current) => current.copyWith(
            category: 'TREATMENT',
            beneficiaryType: 'PET',
            beneficiaryName: 'Tuni',
            title: 'Help Tuni recover',
            story:
                'This is a sufficiently long fundraiser story that satisfies validation.',
            fundingMode: 'ONE_TIME',
            targetAmountMinor: 120000,
            endsAt: DateTime(2026, 9, 1),
            customLocationNote: 'Dhaka, Bangladesh',
            locationText: 'Dhaka, Bangladesh',
          ),
          autosave: false,
        );

        final failed = await controller.submitForReview();
        expect(failed, isNull);
        expect(controller.submissionFailure, isNotNull);
        expect(
          controller.submissionFailure!.message,
          'End date must be a valid future date.',
        );

        final retried = await controller.submitForReview();
        expect(retried, isNotNull);
        expect(controller.submissionFailure, isNull);
      },
    );
  });
}

class _FakeFundraisingRepository extends FundraisingRepository {
  _FakeFundraisingRepository({
    FundraisingAccount? account,
    this.createFailsFirst = false,
    this.submitFailsFirst = false,
    List<FundraisingPayoutMethod>? payoutMethods,
  }) : _account = account,
       _payoutMethods = payoutMethods ?? _activePayoutMethods,
       super(ApiClient(dio: Dio()));

  final FundraisingAccount? _account;
  final List<FundraisingPayoutMethod> _payoutMethods;
  bool createFailsFirst;
  bool submitFailsFirst;
  int createDraftCalls = 0;
  int submitDraftCalls = 0;

  @override
  Future<FundraisingAccount?> fetchMyAccount() async => _account;

  @override
  Future<List<FundraisingPayoutMethod>> listMyPayoutMethods() async =>
      _payoutMethods;

  @override
  Future<FundraisingDraftRecord> createDraft({
    required Map<String, dynamic> payload,
  }) async {
    createDraftCalls += 1;
    if (createFailsFirst && createDraftCalls == 1) {
      throw ApiClientException(
        message: 'Draft save failed',
        code: 'FUNDRAISING_DRAFT_SAVE_FAILED',
        statusCode: 500,
      );
    }
    return _draftRecord(id: createDraftCalls);
  }

  @override
  Future<FundraisingDraftRecord> updateDraft({
    required String draftId,
    required Map<String, dynamic> payload,
  }) async {
    return _draftRecord(id: int.tryParse(draftId) ?? 1);
  }

  @override
  Future<FundraisingDraftRecord> submitDraft({
    required String draftId,
    required String idempotencyKey,
  }) async {
    submitDraftCalls += 1;
    if (submitFailsFirst && submitDraftCalls == 1) {
      throw ApiClientException(
        message: 'Invalid fundraising request.',
        code: 'FUNDRAISING_VALIDATION_ERROR',
        statusCode: 400,
        responseData: <String, dynamic>{
          'success': false,
          'code': 'FUNDRAISING_VALIDATION_ERROR',
          'message': 'Invalid fundraising request.',
          'details': <Map<String, dynamic>>[
            <String, dynamic>{
              'path': 'endsAt',
              'message': 'End date must be a valid future date.',
            },
          ],
        },
      );
    }
    return _draftRecord(
      id: int.tryParse(draftId) ?? 1,
      status: 'PENDING_REVIEW',
    );
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
    presentAddress: 'Dhaka',
    permanentAddress: 'Dhaka',
    occupation: 'Volunteer',
    divisionId: 30,
    districtId: 3026,
    upazilaId: 302601,
    unionId: null,
    areaId: 5001,
    dateOfBirth: DateTime(1995, 1, 1),
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
}

FundraisingDraftRecord _draftRecord({
  required int id,
  String status = 'DRAFT',
}) {
  return FundraisingDraftRecord(
    id: id,
    status: status,
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
