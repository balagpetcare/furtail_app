import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_payout_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:furtail_app/services/api_client.dart';

class FundraisingCreateWizardController extends ChangeNotifier {
  FundraisingCreateWizardController({
    required FundraisingRepository repository,
    required FundraisingDraftRecoveryService recoveryService,
    this.autosaveDelay = const Duration(milliseconds: 900),
  }) : _repository = repository,
       _recoveryService = recoveryService;

  final FundraisingRepository _repository;
  final FundraisingDraftRecoveryService _recoveryService;
  final Duration autosaveDelay;

  Timer? _autosaveTimer;
  bool _initialized = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _hasUnsavedChanges = false;
  FundraisingDraftRecovery _draft = FundraisingDraftRecovery.empty();
  FundraisingAccount? _account;
  List<FundraisingPayoutMethod> _payoutMethods =
      const <FundraisingPayoutMethod>[];
  FundraisingWizardFailure? _lastFailure;
  FundraisingDraftRecord? _serverDraft;

  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isSubmitting => _isSubmitting;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  FundraisingDraftRecovery get draft => _draft;
  FundraisingAccount? get account => _account;
  List<FundraisingPayoutMethod> get payoutMethods => _payoutMethods;
  FundraisingWizardFailure? get lastFailure => _lastFailure;
  FundraisingDraftRecord? get serverDraft => _serverDraft;

  bool get hasActivePayoutMethod =>
      _payoutMethods.any((method) => method.isActive);

  bool get isVerificationRejected =>
      (_account?.status.toUpperCase() ?? '') == 'REJECTED';

  bool get hasVerificationProfile =>
      (_account?.presentAddress?.trim().isNotEmpty ?? false) &&
      (_account?.permanentAddress?.trim().isNotEmpty ?? false) &&
      (_account?.dateOfBirth != null) &&
      (_account?.documents.isNotEmpty ?? false);

  bool get canProceedFromEligibility =>
      !isVerificationRejected && missingVerificationActions.isEmpty;

  List<String> get missingVerificationActions {
    final actions = <String>[];
    final account = _account;
    if (account == null) {
      actions.add('complete_profile');
      actions.add('upload_documents');
      return actions;
    }
    if ((account.presentAddress ?? '').trim().isEmpty ||
        (account.permanentAddress ?? '').trim().isEmpty ||
        account.dateOfBirth == null) {
      actions.add('complete_profile');
    }
    if (account.documents.isEmpty) {
      actions.add('upload_documents');
    }
    if (isVerificationRejected) {
      actions.add('resolve_rejection');
    }
    return actions;
  }

  List<String> validationCodesForStep(
    FundraisingWizardStep step, {
    bool hasBlockingMedia = false,
  }) {
    switch (step) {
      case FundraisingWizardStep.eligibility:
        return canProceedFromEligibility
            ? const <String>[]
            : missingVerificationActions;
      case FundraisingWizardStep.fundraiserType:
        return <String>[
          if (_draft.category.trim().isEmpty) 'category_required',
          if (_draft.beneficiaryType.trim().isEmpty)
            'beneficiary_type_required',
          if (_draft.beneficiaryName.trim().isEmpty)
            'beneficiary_name_required',
        ];
      case FundraisingWizardStep.storyAndGoal:
        return <String>[
          if (_draft.title.trim().length < 6) 'title_too_short',
          if (_draft.story.trim().length < 40) 'story_too_short',
          if ((_draft.targetAmountMinor ?? 0) <= 0) 'target_amount_required',
          if (_draft.deadline == null) 'deadline_required',
        ];
      case FundraisingWizardStep.caseDetails:
        return <String>[
          if ((_draft.estimatedExpenseMinor ?? 0) <= 0)
            'estimated_expense_required',
          if ((_draft.urgency ?? '').trim().isEmpty) 'urgency_required',
        ];
      case FundraisingWizardStep.location:
        return <String>[
          if (_draft.locationText.trim().isEmpty) 'location_required',
        ];
      case FundraisingWizardStep.evidence:
        return <String>[
          if (_draft.mediaIds.isEmpty) 'media_required',
          if (hasBlockingMedia) 'media_blocking',
        ];
      case FundraisingWizardStep.payoutReadiness:
        return <String>[if (!hasActivePayoutMethod) 'add_payout_method'];
      case FundraisingWizardStep.preview:
        final all = <String>[];
        for (final entry in FundraisingWizardStep.values.take(
          FundraisingWizardStep.values.length - 1,
        )) {
          all.addAll(
            validationCodesForStep(entry, hasBlockingMedia: hasBlockingMedia),
          );
        }
        return all.toSet().toList();
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();

    try {
      final recovered = await _recoveryService.load();
      if (recovered != null) {
        _draft = recovered;
      }

      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.fetchMyAccount(),
        _repository.listMyPayoutMethods(),
      ]);
      _account = results[0] as FundraisingAccount;
      _payoutMethods = results[1] as List<FundraisingPayoutMethod>;

      if (_draft.remoteDraftId != null && !_draft.hasMeaningfulContent) {
        final fetched = await _repository.fetchDraft(
          _draft.remoteDraftId!.toString(),
        );
        _serverDraft = fetched;
        _draft = FundraisingDraftRecovery.fromServerDraft(
          fetched,
          base: _draft,
        );
      }
    } catch (error) {
      _lastFailure = _mapError(
        error,
        fallback: FundraisingWizardErrorType.unknown,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDraft(
    FundraisingDraftRecovery Function(FundraisingDraftRecovery current)
    update, {
    bool autosave = true,
  }) async {
    _draft = update(_draft).copyWith(updatedAt: DateTime.now());
    _hasUnsavedChanges = true;
    _lastFailure = null;
    notifyListeners();
    await _recoveryService.save(_draft);
    if (autosave) {
      scheduleAutosave();
    }
  }

  void scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, () {
      unawaited(saveDraftNow());
    });
  }

  Future<void> refreshEligibility() async {
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.fetchMyAccount(),
        _repository.listMyPayoutMethods(),
      ]);
      _account = results[0] as FundraisingAccount;
      _payoutMethods = results[1] as List<FundraisingPayoutMethod>;
      notifyListeners();
    } catch (error) {
      _lastFailure = _mapError(
        error,
        fallback: FundraisingWizardErrorType.unknown,
      );
      notifyListeners();
    }
  }

  Future<void> saveDraftNow() async {
    if (_isSaving || !_draft.hasMeaningfulContent) return;
    if (_draft.remoteDraftId == null &&
        !_hasMinimumRemoteDraftPayload(_draft)) {
      _hasUnsavedChanges = true;
      notifyListeners();
      return;
    }
    _autosaveTimer?.cancel();
    _isSaving = true;
    notifyListeners();

    try {
      final payload = _buildDraftPayload(_draft);
      final FundraisingDraftRecord saved;
      if (_draft.remoteDraftId == null) {
        saved = await _repository.createDraft(payload: payload);
      } else {
        saved = await _repository.updateDraft(
          draftId: _draft.remoteDraftId!.toString(),
          payload: payload,
        );
      }
      _serverDraft = saved;
      _draft = FundraisingDraftRecovery.fromServerDraft(
        saved,
        base: _draft,
      ).copyWith(updatedAt: DateTime.now());
      _hasUnsavedChanges = false;
      _lastFailure = null;
      await _recoveryService.save(_draft);
    } catch (error) {
      _lastFailure = _mapError(
        error,
        fallback: FundraisingWizardErrorType.saveFailed,
      );
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<FundraisingDraftRecord?> submitForReview() async {
    if (_isSubmitting) return _serverDraft;
    _isSubmitting = true;
    _lastFailure = null;
    notifyListeners();

    try {
      await saveDraftNow();
      final draftId = _draft.remoteDraftId;
      if (draftId == null) {
        throw const FormatException('Draft not available');
      }
      final submitted = await _repository.submitDraft(
        draftId: draftId.toString(),
        idempotencyKey:
            _draft.submitIdempotencyKey ??
            'submit-${DateTime.now().microsecondsSinceEpoch}',
      );
      _serverDraft = submitted;
      _draft = FundraisingDraftRecovery.fromServerDraft(
        submitted,
        base: _draft,
      ).copyWith(updatedAt: DateTime.now());
      _hasUnsavedChanges = false;
      await _recoveryService.clear();
      return submitted;
    } catch (error) {
      _lastFailure = _mapError(
        error,
        fallback: FundraisingWizardErrorType.submitFailed,
      );
      notifyListeners();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> clearRecoveredDraft() async {
    _autosaveTimer?.cancel();
    _draft = FundraisingDraftRecovery.empty();
    _hasUnsavedChanges = false;
    _serverDraft = null;
    await _recoveryService.clear();
    notifyListeners();
  }

  Future<void> persistRecovery() {
    return _recoveryService.save(_draft.copyWith(updatedAt: DateTime.now()));
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _buildDraftPayload(FundraisingDraftRecovery draft) {
    final locationText = _normalizedLocationText(draft);
    final targetAmountMinor =
        draft.targetAmountMinor ?? draft.suggestedTargetMinor;
    final spendingLines = draft.expenses
        .where((entry) => (entry.amountMinor ?? 0) > 0)
        .map((entry) => entry.toJson())
        .toList();
    return <String, dynamic>{
      if (draft.createIdempotencyKey != null && draft.remoteDraftId == null)
        'idempotencyKey': draft.createIdempotencyKey,
      'title': draft.title.trim(),
      'caption': draft.story.trim(),
      'category': draft.category.trim(),
      'deadline': (draft.deadline ?? DateTime.now()).toIso8601String(),
      'currencyCode': draft.currencyCode,
      'targetAmountMinor': targetAmountMinor,
      'beneficiaryType': draft.beneficiaryType,
      'beneficiaryName': draft.beneficiaryName.trim(),
      'petId': draft.petId,
      'urgency': draft.urgency,
      'treatmentProvider': draft.treatmentProvider.trim().isEmpty
          ? null
          : draft.treatmentProvider.trim(),
      'estimatedExpenseMinor': draft.estimatedExpenseMinor,
      'spendingPlan': <String, dynamic>{'lines': spendingLines},
      'locationText': locationText,
      'countryId': draft.countryId,
      'stateId': draft.stateId,
      'cityId': draft.cityId,
      'subDistrictId': draft.subDistrictId,
      'bdDivisionId': draft.bdDivisionId,
      'bdDistrictId': draft.bdDistrictId,
      'bdUpazilaId': draft.bdUpazilaId,
      'bdAreaId': draft.bdAreaId,
      'mediaIds': draft.mediaIds,
    };
  }

  bool _hasMinimumRemoteDraftPayload(FundraisingDraftRecovery draft) {
    return draft.title.trim().isNotEmpty &&
        draft.story.trim().isNotEmpty &&
        draft.category.trim().isNotEmpty &&
        draft.beneficiaryType.trim().isNotEmpty &&
        draft.beneficiaryName.trim().isNotEmpty &&
        draft.deadline != null &&
        (_draft.targetAmountMinor ?? 0) > 0 &&
        _normalizedLocationText(draft).trim().isNotEmpty;
  }

  String _normalizedLocationText(FundraisingDraftRecovery draft) {
    final parts = <String>[
      if ((draft.areaName ?? '').trim().isNotEmpty) draft.areaName!.trim(),
      if ((draft.upazilaName ?? '').trim().isNotEmpty)
        draft.upazilaName!.trim(),
      if ((draft.districtName ?? '').trim().isNotEmpty)
        draft.districtName!.trim(),
      if ((draft.divisionName ?? '').trim().isNotEmpty)
        draft.divisionName!.trim(),
      if (draft.customLocationNote.trim().isNotEmpty)
        draft.customLocationNote.trim(),
    ];
    final normalized = <String>[];
    final seen = <String>{};
    for (final entry in parts) {
      final key = entry.toLowerCase();
      if (seen.add(key)) normalized.add(entry);
    }
    return normalized.join(', ');
  }

  FundraisingWizardFailure _mapError(
    Object error, {
    required FundraisingWizardErrorType fallback,
  }) {
    if (error is FundraisingWizardFailure) return error;
    if (error is MediaUploadException) {
      return FundraisingWizardFailure(
        type: FundraisingWizardErrorType.mediaFailure,
        message: error.userMessage,
      );
    }
    if (error is ApiClientException) {
      if (error.isUnauthorized || error.code == 'CENTRAL_TOKEN_EXPIRED') {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.sessionExpired,
          apiCode: error.code,
          message: error.message,
        );
      }
      if (error.isNetworkError) {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.timeout,
          apiCode: error.code,
          message: error.message,
        );
      }
      if (error.isForbidden &&
          (error.code == 'FUNDRAISING_FORBIDDEN' ||
              error.code == 'FUNDRAISING_REVIEW_REQUIRED')) {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.verificationRejected,
          apiCode: error.code,
          message: error.message,
        );
      }
      return FundraisingWizardFailure(
        type: fallback,
        apiCode: error.code,
        message: error.message,
      );
    }
    if (error is TimeoutException) {
      return FundraisingWizardFailure(
        type: FundraisingWizardErrorType.timeout,
        message: error.message,
      );
    }
    return FundraisingWizardFailure(type: fallback, message: error.toString());
  }
}
