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
    final url = existing?.redirectUrl;
    if (existing == null || url == null || url.trim().isEmpty) {
      _lastFailure = const FundraisingDonationFailure(
        type: FundraisingDonationErrorType.unknown,
        message: 'Missing payment provider redirect URL.',
      );
      notifyListeners();
      return false;
    }
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (launched) {
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
    }
    return launched;
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
      if (error.statusCode == 400) {
        return FundraisingDonationFailure(
          type: FundraisingDonationErrorType.validation,
          code: error.code,
          message: error.message,
        );
      }
      return FundraisingDonationFailure(
        type: FundraisingDonationErrorType.paymentFailed,
        code: error.code,
        message: error.message,
      );
    }
    return FundraisingDonationFailure(
      type: FundraisingDonationErrorType.unknown,
      message: error.toString(),
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
