import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:furtail_app/core/analytics/analytics_events.dart';
import 'package:furtail_app/core/analytics/analytics_service.dart';
import 'package:furtail_app/services/api_client.dart';

import '../../data/models/fundraising_donation_models.dart';
import '../../data/repositories/fundraising_repository.dart';
import '../../data/services/fundraising_donation_checkout_storage.dart';

class FundraisingDonationCheckoutController extends ChangeNotifier {
  FundraisingDonationCheckoutController({
    required FundraisingRepository repository,
    required FundraisingDonationCheckoutStorage storage,
    required AnalyticsService analyticsService,
  }) : _repository = repository,
       _storage = storage,
       _analyticsService = analyticsService;

  final FundraisingRepository _repository;
  final FundraisingDonationCheckoutStorage _storage;
  final AnalyticsService _analyticsService;

  bool _initialized = false;
  bool _busy = false;
  FundraisingDonationFailure? _lastFailure;
  FundraisingDonationCheckoutRecord? _activeRecord;
  List<FundraisingDonationCheckoutRecord> _history =
      const <FundraisingDonationCheckoutRecord>[];

  bool get initialized => _initialized;
  bool get busy => _busy;
  FundraisingDonationFailure? get lastFailure => _lastFailure;
  FundraisingDonationCheckoutRecord? get activeRecord => _activeRecord;
  List<FundraisingDonationCheckoutRecord> get history => _history;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _reloadFromStorage();
  }

  Future<FundraisingDonationCheckoutRecord?> startCheckout({
    required int campaignId,
    required String campaignTitle,
    required FundraisingDonationDraft draft,
  }) async {
    if (_busy) return null;
    _busy = true;
    _lastFailure = null;
    notifyListeners();

    final attemptId = _generateAttemptId();
    final now = DateTime.now();
    final seed = FundraisingDonationCheckoutRecord(
      attemptId: attemptId,
      campaignId: campaignId,
      campaignTitle: campaignTitle,
      amountMinor: draft.amountMinor,
      currencyCode: 'BDT',
      isAnonymous: draft.isAnonymous,
      supportMessage: draft.supportMessage.trim(),
      paymentMethodLabel: draft.paymentMethodLabel,
      status: FundraisingDonationCheckoutStatus.created,
      consentAccepted: draft.consentAccepted,
      createdAt: now,
      updatedAt: now,
    );
    await _persist(seed, makeActive: true);

    await _analyticsService.logEvent(
      AnalyticsEvents.fundraisingCheckoutOpened,
      parameters: <String, Object?>{
        AnalyticsEvents.campaignId: campaignId,
        AnalyticsEvents.amount: draft.amountMinor,
        AnalyticsEvents.currency: 'BDT',
        'anonymous': draft.isAnonymous,
      },
    );

    try {
      final response = await _repository.createDonationCheckout(
        campaignId: campaignId,
        amountMinor: draft.amountMinor,
        idempotencyKey: attemptId,
        returnUrl: _returnUrl,
        cancelUrl: _cancelUrl,
      );
      final updated = _mergeResponse(seed, response);
      await _persist(updated, makeActive: !updated.isTerminal);
      await _analyticsService.logEvent(
        AnalyticsEvents.fundraisingIntentCreated,
        parameters: <String, Object?>{
          AnalyticsEvents.campaignId: campaignId,
          AnalyticsEvents.amount: draft.amountMinor,
          AnalyticsEvents.currency: 'BDT',
          'reused': response.reused,
        },
      );
      return updated;
    } catch (error) {
      final failure = _mapFailure(error);
      final updated = seed.copyWith(
        status: failure.type == FundraisingDonationErrorType.cancelled
            ? FundraisingDonationCheckoutStatus.cancelled
            : FundraisingDonationCheckoutStatus.failed,
        updatedAt: DateTime.now(),
        failure: failure,
      );
      await _persist(updated, makeActive: !updated.isTerminal);
      _lastFailure = failure;
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<FundraisingDonationCheckoutRecord?> refreshCheckout(
    String attemptId, {
    bool markProcessing = true,
  }) async {
    final existing = await _storage.loadByAttemptId(attemptId);
    if (existing == null) return null;

    final loading = markProcessing && !existing.isTerminal
        ? existing.copyWith(
            status: FundraisingDonationCheckoutStatus.processing,
            updatedAt: DateTime.now(),
            clearFailure: true,
          )
        : existing;
    await _persist(loading, makeActive: !loading.isTerminal);

    try {
      final response = await _repository.pollDonationCheckout(
        campaignId: existing.campaignId,
        amountMinor: existing.amountMinor,
        idempotencyKey: existing.attemptId,
        returnUrl: _returnUrl,
        cancelUrl: _cancelUrl,
        currencyCode: existing.currencyCode,
      );
      final updated = _mergeResponse(existing, response);
      await _persist(updated, makeActive: !updated.isTerminal);
      if (updated.status == FundraisingDonationCheckoutStatus.succeeded) {
        await _analyticsService.logEvent(
          AnalyticsEvents.fundraisingDonationConfirmed,
          parameters: <String, Object?>{
            AnalyticsEvents.campaignId: updated.campaignId,
            AnalyticsEvents.amount: updated.amountMinor,
            AnalyticsEvents.currency: updated.currencyCode,
            'anonymous': updated.isAnonymous,
          },
        );
      } else if (updated.isTerminal) {
        await _analyticsService.logEvent(
          AnalyticsEvents.fundraisingDonationFailed,
          parameters: <String, Object?>{
            AnalyticsEvents.campaignId: updated.campaignId,
            'status': updated.status.name,
          },
        );
      }
      return updated;
    } catch (error) {
      final failure = _mapFailure(error);
      final updated = existing.copyWith(
        status: failure.type == FundraisingDonationErrorType.cancelled
            ? FundraisingDonationCheckoutStatus.cancelled
            : existing.status,
        updatedAt: DateTime.now(),
        failure: failure,
      );
      _lastFailure = failure;
      await _persist(updated, makeActive: !updated.isTerminal);
      return updated;
    }
  }

  Future<FundraisingDonationCheckoutRecord?> retryCheckout(
    String attemptId,
  ) async {
    final existing = await _storage.loadByAttemptId(attemptId);
    if (existing == null) return null;
    return startCheckout(
      campaignId: existing.campaignId,
      campaignTitle: existing.campaignTitle,
      draft: FundraisingDonationDraft(
        amountMinor: existing.amountMinor,
        isAnonymous: existing.isAnonymous,
        supportMessage: existing.supportMessage,
        consentAccepted: existing.consentAccepted,
        paymentMethodLabel: existing.paymentMethodLabel,
      ),
    );
  }

  Future<bool> openProvider(String attemptId) async {
    final existing = await _storage.loadByAttemptId(attemptId);
    final rawUrl = existing?.redirectUrl?.trim();
    final uri = rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl);
    if (existing == null ||
        uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http')) {
      _lastFailure = const FundraisingDonationFailure(
        type: FundraisingDonationErrorType.validation,
        code: 'PAYMENT_REDIRECT_UNAVAILABLE',
        message:
            'The payment page is not available right now. Please try again shortly.',
      );
      notifyListeners();
      return false;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _lastFailure = const FundraisingDonationFailure(
        type: FundraisingDonationErrorType.unknown,
        code: 'PAYMENT_PROVIDER_OPEN_FAILED',
        message: 'We could not open the payment page. Please try again.',
      );
      notifyListeners();
      return false;
    }

    _lastFailure = null;
    final updated = existing.copyWith(
      status: FundraisingDonationCheckoutStatus.paymentPending,
      updatedAt: DateTime.now(),
      clearFailure: true,
    );
    await _persist(updated, makeActive: !updated.isTerminal);
    await _analyticsService.logEvent(
      AnalyticsEvents.fundraisingProviderOpened,
      parameters: <String, Object?>{
        AnalyticsEvents.campaignId: existing.campaignId,
        'provider': existing.provider ?? 'wpa',
      },
    );
    return true;
  }

  Future<void> markCancelled(String attemptId) async {
    final existing = await _storage.loadByAttemptId(attemptId);
    if (existing == null) return;
    await _persist(
      existing.copyWith(
        status: FundraisingDonationCheckoutStatus.cancelled,
        updatedAt: DateTime.now(),
        failure: const FundraisingDonationFailure(
          type: FundraisingDonationErrorType.cancelled,
        ),
      ),
      makeActive: false,
    );
    await _analyticsService.logEvent(
      AnalyticsEvents.fundraisingCheckoutAbandoned,
      parameters: <String, Object?>{
        AnalyticsEvents.campaignId: existing.campaignId,
        'status': FundraisingDonationCheckoutStatus.cancelled.name,
      },
    );
  }

  Future<void> clearActiveAttempt() async {
    _activeRecord = null;
    await _storage.setActiveAttemptId(null);
    notifyListeners();
  }

  Future<void> _persist(
    FundraisingDonationCheckoutRecord record, {
    required bool makeActive,
  }) async {
    await _storage.upsert(record);
    await _storage.setActiveAttemptId(makeActive ? record.attemptId : null);
    await _reloadFromStorage();
  }

  Future<void> _reloadFromStorage() async {
    _history = await _storage.loadAll();
    _activeRecord = await _storage.loadActiveAttempt();
    notifyListeners();
  }

  FundraisingDonationCheckoutRecord _mergeResponse(
    FundraisingDonationCheckoutRecord seed,
    FundraisingDonationCheckoutResponse response,
  ) {
    final intent = response.donationIntent;
    final status = _mapServerStatus(intent.status, intent.expiresAt);
    return seed.copyWith(
      intentId: intent.id,
      intentPublicId: intent.publicId,
      referenceId: intent.referenceId,
      provider: response.payment?.provider ?? seed.provider ?? 'wpa',
      redirectUrl: response.payment?.redirectUrl ?? seed.redirectUrl,
      expiresAt: intent.expiresAt,
      confirmedAt:
          status == FundraisingDonationCheckoutStatus.succeeded ||
              status == FundraisingDonationCheckoutStatus.onHoldReview
          ? (intent.finalizedAt ?? intent.updatedAt ?? DateTime.now())
          : seed.confirmedAt,
      status: status,
      updatedAt: DateTime.now(),
      clearFailure: true,
    );
  }

  FundraisingDonationCheckoutStatus _mapServerStatus(
    String rawStatus,
    DateTime expiresAt,
  ) {
    final status = rawStatus.trim().toUpperCase();
    if (status == 'SUCCEEDED') {
      return FundraisingDonationCheckoutStatus.succeeded;
    }
    if (status == 'FAILED' || status == 'REFUNDED' || status == 'CHARGEDBACK') {
      return FundraisingDonationCheckoutStatus.failed;
    }
    if (status == 'CANCELLED') {
      return FundraisingDonationCheckoutStatus.cancelled;
    }
    if (status == 'EXPIRED' || expiresAt.isBefore(DateTime.now())) {
      return FundraisingDonationCheckoutStatus.expired;
    }
    if (status == 'PROCESSING') {
      return FundraisingDonationCheckoutStatus.processing;
    }
    if (status.contains('HOLD') || status.contains('REVIEW')) {
      return FundraisingDonationCheckoutStatus.onHoldReview;
    }
    return FundraisingDonationCheckoutStatus.paymentPending;
  }

  FundraisingDonationFailure _mapFailure(Object error) {
    if (error is ApiClientException) {
      if (error.statusCode == 401 ||
          error.code == 'CENTRAL_TOKEN_EXPIRED' ||
          error.code == 'TOKEN_NOT_FOUND') {
        return const FundraisingDonationFailure(
          type: FundraisingDonationErrorType.sessionExpired,
          message: 'Your session has expired. Please sign in again.',
        );
      }
      if (error.dioExceptionType == 'connectionTimeout' ||
          error.dioExceptionType == 'receiveTimeout' ||
          error.dioExceptionType == 'sendTimeout') {
        return const FundraisingDonationFailure(
          type: FundraisingDonationErrorType.timeout,
          message: 'The payment request timed out. Please try again.',
        );
      }
      if (error.isNetworkError) {
        return const FundraisingDonationFailure(
          type: FundraisingDonationErrorType.offline,
          message: 'Please check your connection and try the payment again.',
        );
      }

      // Map specific donation error codes to user-friendly messages
      final errorMessages = <String, String>{
        'CAMPAIGN_NOT_FOUND': 'This fundraiser does not exist.',
        'CAMPAIGN_DELETED': 'This fundraiser has been removed.',
        'CAMPAIGN_STATUS_DRAFT':
            'This fundraiser is still a draft and cannot receive donations.',
        'CAMPAIGN_STATUS_PENDING_REVIEW':
            'This fundraiser is available for donations while review is pending.',
        'CAMPAIGN_STATUS_PAUSED':
            'This fundraiser is paused and not accepting donations.',
        'CAMPAIGN_STATUS_FUNDED':
            'This fundraiser reached its goal and is not accepting more donations.',
        'CAMPAIGN_STATUS_COMPLETED': 'This fundraiser has been completed.',
        'CAMPAIGN_STATUS_EXPIRED': 'This fundraiser has expired.',
        'CAMPAIGN_STATUS_REJECTED':
            'This fundraiser was rejected and cannot receive donations.',
        'CAMPAIGN_STATUS_CANCELLED': 'This fundraiser has been cancelled.',
        'CAMPAIGN_STATUS_SUSPENDED': 'This fundraiser is suspended.',
        'CAMPAIGN_STATUS_ARCHIVED': 'This fundraiser is archived.',
        'PAYMENT_PROVIDER_ERROR': 'Payment provider error. Please try again.',
        'INVALID_REDIRECT_URL':
            'Payment configuration error. Please contact support.',
        'DONATION_VALIDATION_FAILED': 'Please enter a valid donation amount.',
      };

      // Check for mapped error codes
      if (error.code != null && errorMessages.containsKey(error.code)) {
        return FundraisingDonationFailure(
          type: FundraisingDonationErrorType.validation,
          code: error.code,
          message: errorMessages[error.code]!,
        );
      }

      // Handle generic status codes
      if (error.statusCode == 400) {
        final message = error.message.trim();
        return FundraisingDonationFailure(
          type: FundraisingDonationErrorType.validation,
          code: error.code,
          message: message.isNotEmpty
              ? message
              : 'Invalid donation request. Please try again.',
        );
      }
      if (error.statusCode == 404) {
        return FundraisingDonationFailure(
          type: FundraisingDonationErrorType.validation,
          code: error.code,
          message: 'This fundraiser could not be found.',
        );
      }

      final message = error.message.trim();
      return FundraisingDonationFailure(
        type: FundraisingDonationErrorType.paymentFailed,
        code: error.code,
        message: message.isNotEmpty
            ? message
            : 'Payment failed. Please try again.',
      );
    }
    return const FundraisingDonationFailure(
      type: FundraisingDonationErrorType.unknown,
      message:
          'Something went wrong while starting the payment. Please try again.',
    );
  }

  String _generateAttemptId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = Random.secure().nextInt(1 << 32).toRadixString(36);
    return 'frdon-$timestamp-$entropy';
  }

  static const String _returnUrl = 'furtail://fundraising/checkout/success';
  static const String _cancelUrl = 'furtail://fundraising/checkout/cancel';
}
