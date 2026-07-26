import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/fundraising_debug_logger.dart';
import 'package:furtail_app/features/fundraising/data/fundraising_error_mapper.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_payout_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_date_serializer.dart';
import 'package:furtail_app/features/media/composer/fundraising_media_validation.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:furtail_app/services/api_client.dart';

/// Builds the sanitized, debug-only diagnostic string for a failed
/// fundraising eligibility request, or `null` if [error] isn't a network
/// failure this diagnostic applies to.
///
/// Only ever includes: HTTP method, request path, resolved host, resolved
/// port, the Dio exception-type name, and an HTTP status code if present.
/// Deliberately never includes: the access/refresh token, cookies, the
/// Authorization header, request/response bodies, or a stack trace — none
/// of those are read from [error] at all, so they cannot leak here even if
/// [error] happens to carry them.
///
/// Exposed at top level (rather than kept private) specifically so tests
/// can assert on its output without depending on `kDebugMode`/`dart:developer`.
@visibleForTesting
String? buildFundraisingEligibilityDebugLog(Object error) {
  String method = 'GET';
  String? url;
  String dioType = 'n/a';
  Object? statusCode = 'n/a';

  if (error is ApiClientException) {
    method = error.method ?? method;
    url = error.url;
    dioType = error.dioExceptionType ?? dioType;
    statusCode = error.statusCode ?? statusCode;
  } else if (error is DioException) {
    // ApiClient only wraps `badResponse` (HTTP-level) failures into
    // ApiClientException — connection-level failures (connectionError,
    // timeouts, etc.) propagate as a raw DioException, which is exactly
    // the "can't reach the API" case this diagnostic exists for.
    method = error.requestOptions.method;
    url = error.requestOptions.path;
    dioType = error.type.name;
    statusCode = error.response?.statusCode ?? 'n/a';
  } else {
    return null;
  }

  final parsed = url == null ? null : Uri.tryParse(url);
  final host = (parsed?.host.isNotEmpty ?? false) ? parsed!.host : null;
  final port = (parsed?.hasPort ?? false) ? parsed!.port : null;
  final path = parsed == null
      ? 'unknown'
      : (parsed.path.isEmpty ? '/' : parsed.path);

  return 'Fundraising eligibility request failed: '
      'method=$method '
      'path=$path '
      'host=${host ?? 'unknown'} '
      'port=${port ?? 'unknown'} '
      'dioExceptionType=$dioType '
      'statusCode=$statusCode';
}

/// Explicit, mutually-exclusive eligibility-loading states for Step 1.
///
/// [loaded] takes precedence once an account has ever been fetched
/// successfully — a later failed *refresh* never regresses the UI back to
/// [error] while good data is already on screen (see [isEligibilityRefreshing]
/// for the subtle in-place refresh indicator instead).
enum FundraisingEligibilityLoadState { initial, loading, loaded, error }

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
  FundraisingDraftRecord? _serverDraft;

  // Scoped failures — each operation owns its own failure slot so that,
  // for example, a failed draft-restore fetch can never surface as a
  // banner over successfully-loaded eligibility data (and vice versa).
  bool _eligibilityLoading = false;
  bool _eligibilityRefreshing = false;
  FundraisingWizardFailure? _eligibilityFailure;
  FundraisingWizardFailure? _draftFailure;
  FundraisingWizardFailure? _submissionFailure;

  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isSubmitting => _isSubmitting;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  FundraisingDraftRecovery get draft => _draft;
  FundraisingAccount? get account => _account;
  List<FundraisingPayoutMethod> get payoutMethods => _payoutMethods;
  FundraisingDraftRecord? get serverDraft => _serverDraft;

  void seedAccount(FundraisingAccount? account) {
    _account = account;
  }

  /// Explicit eligibility load state for Step 1. See
  /// [FundraisingEligibilityLoadState] for the state semantics.
  FundraisingEligibilityLoadState get eligibilityLoadState {
    if (_account != null) return FundraisingEligibilityLoadState.loaded;
    if (_eligibilityLoading) return FundraisingEligibilityLoadState.loading;
    if (_eligibilityFailure != null) {
      return FundraisingEligibilityLoadState.error;
    }
    return FundraisingEligibilityLoadState.initial;
  }

  /// True while a refresh is in flight *after* eligibility has already
  /// loaded once — used to show a subtle indicator instead of replacing
  /// already-loaded content.
  bool get isEligibilityRefreshing => _eligibilityRefreshing;

  /// Only set when the eligibility-scoped fetch (account + payout methods)
  /// fails. Never populated by draft-restore, autosave, save, or submission
  /// failures.
  FundraisingWizardFailure? get eligibilityFailure => _eligibilityFailure;

  /// Draft bootstrap/restore, autosave, and manual Save Draft failures.
  FundraisingWizardFailure? get draftFailure => _draftFailure;

  /// Campaign submission failures only.
  FundraisingWizardFailure? get submissionFailure => _submissionFailure;

  bool get hasActivePayoutMethod =>
      _payoutMethods.any((method) => method.isActive);

  bool get isVerificationRejected => readiness.isRejected;

  bool get hasVerificationProfile => readiness.requiredProfileComplete;

  bool get canStartFundraiser => readiness.canStartFundraiser;

  bool get canProceedFromEligibility => canStartFundraiser;

  FundraisingAccountReadiness get readiness =>
      FundraisingAccountReadiness.fromAccount(_account);

  List<String> get missingVerificationActions {
    final actions = <String>[
      if (!readiness.requiredProfileComplete) 'complete_profile',
      if (!readiness.requiredDocumentsUploaded) 'upload_documents',
      if (readiness.isRejected) 'resolve_rejection',
    ];
    return actions;
  }

  /// Validation codes blocking [step]. [mediaValidation] — the fundraiser's
  /// pure media-readiness result (see `evaluateFundraisingMedia`) — is only
  /// consulted for the [FundraisingWizardStep.location] step (which also
  /// hosts media/evidence pickers in this wizard) and the aggregated
  /// [FundraisingWizardStep.preview] step. It never gates on account
  /// verification status or payout methods — neither is required to create
  /// or submit a fundraiser.
  List<String> validationCodesForStep(
    FundraisingWizardStep step, {
    FundraisingMediaValidationResult? mediaValidation,
  }) {
    switch (step) {
      case FundraisingWizardStep.fundraiserType:
        return <String>[
          if (_draft.category.trim().isEmpty) 'category_required',
          if (_draft.beneficiaryType.trim().isEmpty)
            'beneficiary_type_required',
          if (_draft.beneficiaryName.trim().isEmpty)
            'beneficiary_name_required',
          if (_draft.title.trim().length < 6) 'title_too_short',
          if (_draft.story.trim().length < 40) 'story_too_short',
          if (_draft.fundingMode.trim().toUpperCase() != 'ONGOING' &&
              (_draft.targetAmountMinor ?? 0) <= 0)
            'target_amount_required',
          if (_draft.fundingMode.trim().toUpperCase() != 'ONGOING' &&
              (_draft.endsAt ?? _draft.deadline) == null)
            'deadline_required',
        ];
      case FundraisingWizardStep.location:
        return <String>[
          if (_draft.locationText.trim().isEmpty) 'location_required',
          if (mediaValidation != null && !mediaValidation.hasAnyItem)
            'media_required',
          if (mediaValidation != null &&
              mediaValidation.hasAnyItem &&
              (mediaValidation.hasFailedItems ||
                  mediaValidation.hasPendingItems))
            'media_blocking',
        ];
      case FundraisingWizardStep.preview:
        final all = <String>[];
        for (final entry in const <FundraisingWizardStep>[
          FundraisingWizardStep.fundraiserType,
          FundraisingWizardStep.location,
        ]) {
          all.addAll(
            validationCodesForStep(entry, mediaValidation: mediaValidation),
          );
        }
        return all.toSet().toList();
      default:
        return const <String>[];
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
    } catch (_) {
      // A corrupt/unreadable local recovery copy is non-fatal — continue
      // with an empty draft rather than surfacing this as an eligibility
      // or draft failure.
    }

    // Eligibility checking is independent of, and must never be tainted by,
    // draft bootstrap/restoration below — each keeps its own failure slot.
    await _loadEligibility();

    if (_draft.remoteDraftId != null && !_draft.hasMeaningfulContent) {
      try {
        final fetched = await _repository.fetchDraft(
          _draft.remoteDraftId!.toString(),
        );
        _serverDraft = fetched;
        _draft = FundraisingDraftRecovery.fromServerDraft(
          fetched,
          base: _draft,
        );
        _draftFailure = null;
      } catch (error) {
        _draftFailure = _mapError(
          error,
          fallback: FundraisingWizardErrorType.unknown,
        );
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetches the fundraising account + payout methods and updates
  /// [eligibilityLoadState] accordingly. Never creates a server-side draft —
  /// eligibility checking is independent of fundraiser-draft creation.
  Future<void> _loadEligibility() async {
    final isRefreshOfExisting = _account != null;
    if (isRefreshOfExisting) {
      _eligibilityRefreshing = true;
    } else {
      _eligibilityLoading = true;
    }
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.fetchMyAccount(),
        _repository.listMyPayoutMethods(),
      ]);
      _account = results[0] as FundraisingAccount?;
      _payoutMethods = results[1] as List<FundraisingPayoutMethod>;
      _eligibilityFailure = null;
    } catch (error) {
      _eligibilityFailure = _mapError(
        error,
        fallback: FundraisingWizardErrorType.unknown,
      );
      _logEligibilityFailureForDebug(error);
    } finally {
      _eligibilityLoading = false;
      _eligibilityRefreshing = false;
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
    _draftFailure = null;
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

  Future<void>? _refreshEligibilityInFlight;

  /// Re-fetches the fundraising account + payout methods and recomputes
  /// eligibility. Safe to call after returning from profile/document/payout
  /// setup screens; concurrent calls share a single in-flight request so a
  /// refresh is never duplicated.
  Future<void> refreshEligibility() {
    final existing = _refreshEligibilityInFlight;
    if (existing != null) return existing;
    final future = _loadEligibility().whenComplete(() {
      _refreshEligibilityInFlight = null;
    });
    _refreshEligibilityInFlight = future;
    return future;
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
      await _recoveryService.save(_draft.copyWith(updatedAt: DateTime.now()));
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
      _draftFailure = null;
      await _recoveryService.save(_draft);
    } catch (error) {
      _draftFailure = _mapError(
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
    _submissionFailure = null;
    notifyListeners();

    try {
      await saveDraftNow();
      if (_draftFailure != null) {
        _submissionFailure = _draftFailure;
        return null;
      }
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
      _submissionFailure = _mapError(
        error,
        fallback: FundraisingWizardErrorType.submitFailed,
      );
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
    final mode = draft.fundingMode.trim().toUpperCase();
    final oneTime = mode.isEmpty || mode == 'ONE_TIME';
    final targetAmountMinor = oneTime
        ? (draft.targetAmountMinor ?? draft.suggestedTargetMinor)
        : draft.targetAmountMinor;
    final spendingLines = draft.expenses
        .where((entry) => (entry.amountMinor ?? 0) > 0)
        .map((entry) => entry.toJson())
        .toList();

    final endDateTime = draft.endsAt ?? draft.deadline;
    final payload = <String, dynamic>{
      if (draft.createIdempotencyKey != null && draft.remoteDraftId == null)
        'idempotencyKey': draft.createIdempotencyKey,
      'title': draft.title.trim(),
      'caption': draft.story.trim(),
      'category': draft.category.trim(),
      'fundingMode': draft.fundingMode.trim().isEmpty
          ? 'ONE_TIME'
          : draft.fundingMode.trim().toUpperCase(),
      if (draft.startsAt != null)
        'startsAt': FundraisingDateSerializer.serializeToUtcIso8601(
          draft.startsAt,
        ),
      if (endDateTime != null)
        'endsAt': FundraisingDateSerializer.serializeToUtcIso8601(endDateTime),
      if (endDateTime != null)
        'deadline': FundraisingDateSerializer.serializeToUtcIso8601(
          endDateTime,
        ),
      'currencyCode': draft.currencyCode,
      if (targetAmountMinor != null) 'targetAmountMinor': targetAmountMinor,
      if (draft.monthlyGoalMinor != null)
        'monthlyGoalMinor': draft.monthlyGoalMinor,
      if (draft.nextReviewAt != null)
        'nextReviewAt': FundraisingDateSerializer.serializeToUtcIso8601(
          draft.nextReviewAt,
        ),
      'beneficiaryType': draft.beneficiaryType,
      'beneficiaryName': draft.beneficiaryName.trim(),
      'petId': draft.petId,
      'urgency': draft.urgency,
      'treatmentProvider': draft.treatmentProvider.trim().isEmpty
          ? null
          : draft.treatmentProvider.trim(),
      'estimatedExpenseMinor': draft.estimatedExpenseMinor,
      'expenseNotes': draft.expenseNotes.trim().isEmpty
          ? null
          : draft.expenseNotes.trim(),
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
      'securityLatitude': draft.securityLatitude,
      'securityLongitude': draft.securityLongitude,
      'securityLocationAccuracy': draft.securityLocationAccuracy,
      if (draft.securityLocationCapturedAt != null)
        'securityLocationCapturedAt':
            FundraisingDateSerializer.serializeToUtcIso8601(
              draft.securityLocationCapturedAt,
            ),
      'mediaIds': draft.mediaIds,
    };

    FundraisingDateSerializer.logSerializedDateFields(payload);
    return payload;
  }

  bool _hasMinimumRemoteDraftPayload(FundraisingDraftRecovery draft) {
    final mode = draft.fundingMode.trim().toUpperCase();
    final oneTime = mode.isEmpty || mode == 'ONE_TIME';
    final durationReady =
        !oneTime ||
        ((draft.endsAt ?? draft.deadline) != null &&
            (draft.targetAmountMinor ?? draft.suggestedTargetMinor) > 0);
    return draft.title.trim().isNotEmpty &&
        draft.story.trim().isNotEmpty &&
        draft.category.trim().isNotEmpty &&
        draft.beneficiaryType.trim().isNotEmpty &&
        draft.beneficiaryName.trim().isNotEmpty &&
        durationReady &&
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

  /// Debug-only, sanitized diagnostic for a failed eligibility request.
  /// Never runs in release builds (`kDebugMode`-gated) and never reaches
  /// user-facing UI.
  void _logEligibilityFailureForDebug(Object error) {
    logFundraisingRequestDebug(
      operation: 'fundraising.eligibility',
      method: 'GET',
      endpointPath: 'GET /fundraising/account/me',
      error: error,
    );
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
      final code = (error.code ?? '').trim().toUpperCase();

      // Check backend error codes FIRST (before HTTP status)
      if (error.isUnauthorized || code == 'CENTRAL_TOKEN_EXPIRED') {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.sessionExpired,
          apiCode: error.code,
          message: 'Your session has expired. Please sign in again.',
        );
      }

      if (code == 'FUNDRAISING_ACCOUNT_INCOMPLETE') {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.validation,
          apiCode: error.code,
          message: 'Complete your fundraising profile before saving a draft.',
        );
      }

      if (code == 'FUNDRAISING_FORBIDDEN') {
        final responseData = error.responseData is Map
            ? Map<String, dynamic>.from(error.responseData as Map)
            : null;
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.verificationRejected,
          apiCode: error.code,
          message:
              (responseData?['message']?.toString()) ??
              'Your fundraising account is restricted.',
        );
      }

      if (code == 'FUNDRAISING_SCHEMA_UNAVAILABLE') {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.unknown,
          apiCode: error.code,
          message:
              'Fundraising is temporarily unavailable. Please try again shortly.',
        );
      }

      if (code == 'FUNDRAISING_REQUEST_FAILED') {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.unknown,
          apiCode: error.code,
          message:
              'The fundraising service could not complete the request. Please try again.',
        );
      }

      if (code == 'FUNDRAISING_DRAFT_SAVE_FAILED') {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.saveFailed,
          apiCode: error.code,
          message: 'We could not save this draft right now. Please try again.',
        );
      }

      if (code == 'FUNDRAISING_VALIDATION_ERROR') {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.validation,
          apiCode: error.code,
          message:
              fundraisingValidationDetailMessage(error) ??
              'Please check the highlighted details and try again.',
        );
      }

      // Now check network errors
      if (error.isNetworkError) {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.timeout,
          apiCode: error.code,
          message: 'We could not reach the server. Please try again.',
        );
      }

      // Finally check generic HTTP status codes
      if ((error.statusCode ?? 0) >= 500) {
        return FundraisingWizardFailure(
          type: fallback,
          apiCode: error.code,
          message:
              'The service is temporarily unavailable. Please try again shortly.',
        );
      }

      if ((error.statusCode ?? 0) == 400 || (error.statusCode ?? 0) == 422) {
        return FundraisingWizardFailure(
          type: fallback,
          apiCode: error.code,
          message: 'Please check the highlighted details and try again.',
        );
      }

      if ((error.statusCode ?? 0) == 403) {
        return FundraisingWizardFailure(
          type: FundraisingWizardErrorType.verificationRejected,
          apiCode: error.code,
          message:
              'Your fundraising account is restricted. Please contact support.',
        );
      }

      return FundraisingWizardFailure(
        type: fallback,
        apiCode: error.code,
        message: 'Something went wrong. Please try again.',
      );
    }
    if (error is TimeoutException) {
      return FundraisingWizardFailure(
        type: FundraisingWizardErrorType.timeout,
        message: error.message ?? 'The request timed out. Please try again.',
      );
    }
    return FundraisingWizardFailure(
      type: fallback,
      message: 'Something went wrong. Please try again.',
    );
  }
}
