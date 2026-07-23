import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_payout_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  group('FundraisingCreateWizardController', () {
    test('restores an unfinished remote draft on initialize', () async {
      final recovery = _InMemoryRecoveryService(
        FundraisingDraftRecovery.empty().copyWith(
          remoteDraftId: 42,
          clearTargetAmountMinor: true,
          title: '',
          story: '',
          category: '',
          beneficiaryName: '',
          mediaIds: const <int>[],
        ),
      );
      final repository = _FakeFundraisingRepository(
        fetchDraftHandler: (_) async => _draftRecord(
          id: 42,
          title: 'Emergency surgery for Tuni',
          caption:
              'Tuni needs urgent surgery and monitored recovery support right away.',
          mediaIds: const <int>[11],
        ),
      );
      final controller = FundraisingCreateWizardController(
        repository: repository,
        recoveryService: recovery,
      );

      await controller.initialize();

      expect(controller.draft.remoteDraftId, 42);
      expect(controller.draft.title, 'Emergency surgery for Tuni');
      expect(controller.draft.story, contains('urgent surgery'));
      expect(controller.draft.mediaIds, const <int>[11]);
      expect(repository.fetchDraftCalls, 1);
    });

    test('submitForReview clears recovery after a successful submission', () async {
      final recovery = _InMemoryRecoveryService(
        _completeDraft(stepIndex: FundraisingWizardStep.preview.index),
      );
      final repository = _FakeFundraisingRepository(
        createDraftHandler: (_) async => _draftRecord(
          id: 77,
          status: 'DRAFT',
          title: 'Campaign draft',
          caption:
              'This fundraiser already has enough detail to create a draft safely.',
          mediaIds: const <int>[91],
        ),
        submitDraftHandler: (draftId, idempotencyKey) async => _draftRecord(
          id: 77,
          status: 'PENDING_REVIEW',
          title: 'Campaign draft',
          caption:
              'This fundraiser already has enough detail to create a draft safely.',
          mediaIds: const <int>[91],
        ),
      );
      final controller = FundraisingCreateWizardController(
        repository: repository,
        recoveryService: recovery,
      );

      await controller.initialize();
      final submitted = await controller.submitForReview();

      expect(submitted, isNotNull);
      expect(submitted!.status, 'PENDING_REVIEW');
      expect(controller.hasUnsavedChanges, isFalse);
      expect(recovery.saved, isNull);
      expect(repository.createDraftCalls, 1);
      expect(repository.submitDraftCalls, 1);
    });

    test('reports story-step validation requirements', () async {
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(),
        recoveryService: _InMemoryRecoveryService(
          FundraisingDraftRecovery.empty().copyWith(
            category: 'TREATMENT',
            beneficiaryType: 'PET',
            beneficiaryName: 'Tuni',
          ),
        ),
      );

      await controller.initialize();

      expect(
        controller.validationCodesForStep(FundraisingWizardStep.storyAndGoal),
        containsAll(<String>[
          'title_too_short',
          'story_too_short',
          'target_amount_required',
          'deadline_required',
        ]),
      );
    });

    test('reports blocking-media validation for the evidence step', () async {
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(),
        recoveryService: _InMemoryRecoveryService(
          _completeDraft(stepIndex: FundraisingWizardStep.evidence.index),
        ),
      );

      await controller.initialize();

      expect(
        controller.validationCodesForStep(
          FundraisingWizardStep.evidence,
          hasBlockingMedia: true,
        ),
        contains('media_blocking'),
      );
    });

    test('maps session expiration safely during submission', () async {
      final recovery = _InMemoryRecoveryService(
        _completeDraft(stepIndex: FundraisingWizardStep.preview.index),
      );
      final controller = FundraisingCreateWizardController(
        repository: _FakeFundraisingRepository(
          createDraftHandler: (_) async => _draftRecord(
            id: 71,
            title: 'Ready draft',
            caption:
                'This fundraiser has enough detail to create a backend draft first.',
            mediaIds: const <int>[91],
          ),
          submitDraftHandler: (draftId, idempotencyKey) async {
            throw ApiClientException(
              message: 'Expired session',
              statusCode: 401,
              code: 'CENTRAL_TOKEN_EXPIRED',
            );
          },
        ),
        recoveryService: recovery,
      );

      await controller.initialize();
      final submitted = await controller.submitForReview();

      expect(submitted, isNull);
      expect(
        controller.lastFailure?.type,
        FundraisingWizardErrorType.sessionExpired,
      );
    });
  });
}

class _FakeFundraisingRepository extends FundraisingRepository {
  _FakeFundraisingRepository({
    this.fetchDraftHandler,
    this.createDraftHandler,
    this.submitDraftHandler,
    FundraisingAccount? account,
    List<FundraisingPayoutMethod>? payoutMethods,
  }) : _account = account ?? _verifiedAccount,
       _payoutMethods = payoutMethods ?? _activePayoutMethods,
       super(ApiClient(dio: Dio()));

  final Future<FundraisingDraftRecord> Function(String draftId)?
  fetchDraftHandler;
  final Future<FundraisingDraftRecord> Function(Map<String, dynamic> payload)?
  createDraftHandler;
  final Future<FundraisingDraftRecord> Function(
    String draftId,
    String idempotencyKey,
  )?
  submitDraftHandler;
  final FundraisingAccount _account;
  final List<FundraisingPayoutMethod> _payoutMethods;

  int fetchDraftCalls = 0;
  int createDraftCalls = 0;
  int submitDraftCalls = 0;

  @override
  Future<FundraisingAccount> fetchMyAccount() async => _account;

  @override
  Future<List<FundraisingPayoutMethod>> listMyPayoutMethods() async =>
      _payoutMethods;

  @override
  Future<FundraisingDraftRecord> fetchDraft(String draftId) async {
    fetchDraftCalls += 1;
    return fetchDraftHandler?.call(draftId) ??
        _draftRecord(id: int.parse(draftId));
  }

  @override
  Future<FundraisingDraftRecord> createDraft({
    required Map<String, dynamic> payload,
  }) async {
    createDraftCalls += 1;
    return createDraftHandler?.call(payload) ?? _draftRecord(id: 1);
  }

  @override
  Future<FundraisingDraftRecord> submitDraft({
    required String draftId,
    required String idempotencyKey,
  }) async {
    submitDraftCalls += 1;
    return submitDraftHandler?.call(draftId, idempotencyKey) ??
        _draftRecord(id: int.parse(draftId), status: 'PENDING_REVIEW');
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

FundraisingDraftRecovery _completeDraft({required int stepIndex}) {
  return FundraisingDraftRecovery.empty().copyWith(
    stepIndex: stepIndex,
    title: 'Emergency care for Tuni',
    story:
        'Tuni needs treatment, medicines, and follow-up care after a rescue injury.',
    category: 'TREATMENT',
    beneficiaryType: 'PET',
    beneficiaryName: 'Tuni',
    targetAmountMinor: 120000,
    deadline: DateTime(2026, 9, 1),
    urgency: 'HIGH',
    estimatedExpenseMinor: 120000,
    treatmentProvider: 'Dhaka Pet Hospital',
    locationText: 'Dhaka, Bangladesh',
    bdDivisionId: 30,
    bdDistrictId: 3026,
    bdUpazilaId: 302601,
    areaName: 'Dhanmondi',
    mediaIds: const <int>[91],
  );
}

FundraisingDraftRecord _draftRecord({
  required int id,
  String status = 'DRAFT',
  String title = 'Draft title',
  String caption = 'Draft caption with enough detail to satisfy validation.',
  List<int> mediaIds = const <int>[],
}) {
  return FundraisingDraftRecord(
    id: id,
    status: status,
    publicId: 'pub-$id',
    slug: 'draft-$id',
    title: title,
    caption: caption,
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
    submittedAt: status == 'PENDING_REVIEW' ? DateTime(2026, 7, 23) : null,
    mediaIds: mediaIds,
  );
}

const FundraisingAccount _verifiedAccount = FundraisingAccount(
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
  dateOfBirth: null,
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
        isDefault: true,
        isActive: true,
      ),
    ];
