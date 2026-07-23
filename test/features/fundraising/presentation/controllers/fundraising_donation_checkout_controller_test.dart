import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/analytics/analytics_service.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_donation_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_donation_checkout_storage.dart';
import 'package:furtail_app/features/fundraising/presentation/controllers/fundraising_donation_checkout_controller.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  group('FundraisingDonationCheckoutController', () {
    test('stores a successful checkout attempt', () async {
      final repository = _FakeDonationRepository(
        createHandler:
            ({
              required campaignId,
              required amountMinor,
              required idempotencyKey,
              required returnUrl,
              required cancelUrl,
              required currencyCode,
            }) async {
              return _response(
                status: 'SUCCEEDED',
                amountMinor: amountMinor,
                idempotencyKey: idempotencyKey,
              );
            },
      );
      final controller = FundraisingDonationCheckoutController(
        repository: repository,
        storage: _InMemoryCheckoutStorage(),
        analyticsService: AnalyticsService.instance,
      );

      final record = await controller.startCheckout(
        campaignId: 15,
        campaignTitle: 'Emergency care',
        draft: const FundraisingDonationDraft(
          amountMinor: 500,
          isAnonymous: false,
          supportMessage: 'Stay strong',
          consentAccepted: true,
          paymentMethodLabel: 'Online payment',
        ),
      );

      expect(record, isNotNull);
      expect(record!.status, FundraisingDonationCheckoutStatus.succeeded);
      expect(controller.history, hasLength(1));
      expect(controller.activeRecord, isNull);
    });

    test('keeps pending checkout recoverable', () async {
      final controller = FundraisingDonationCheckoutController(
        repository: _FakeDonationRepository(
          createHandler:
              ({
                required campaignId,
                required amountMinor,
                required idempotencyKey,
                required returnUrl,
                required cancelUrl,
                required currencyCode,
              }) async {
                return _response(
                  status: 'PENDING',
                  amountMinor: amountMinor,
                  idempotencyKey: idempotencyKey,
                );
              },
        ),
        storage: _InMemoryCheckoutStorage(),
        analyticsService: AnalyticsService.instance,
      );

      final record = await controller.startCheckout(
        campaignId: 18,
        campaignTitle: 'Pending fundraiser',
        draft: const FundraisingDonationDraft(
          amountMinor: 300,
          isAnonymous: true,
          supportMessage: '',
          consentAccepted: true,
          paymentMethodLabel: 'Online payment',
        ),
      );

      expect(record, isNotNull);
      expect(record!.status, FundraisingDonationCheckoutStatus.paymentPending);
      expect(controller.activeRecord?.attemptId, record.attemptId);
    });

    test('markCancelled updates a pending attempt', () async {
      final storage = _InMemoryCheckoutStorage();
      final controller = FundraisingDonationCheckoutController(
        repository: _FakeDonationRepository(
          createHandler:
              ({
                required campaignId,
                required amountMinor,
                required idempotencyKey,
                required returnUrl,
                required cancelUrl,
                required currencyCode,
              }) async {
                return _response(
                  status: 'PENDING',
                  amountMinor: amountMinor,
                  idempotencyKey: idempotencyKey,
                );
              },
        ),
        storage: storage,
        analyticsService: AnalyticsService.instance,
      );

      final record = await controller.startCheckout(
        campaignId: 21,
        campaignTitle: 'Cancel fundraiser',
        draft: const FundraisingDonationDraft(
          amountMinor: 1000,
          isAnonymous: false,
          supportMessage: '',
          consentAccepted: true,
          paymentMethodLabel: 'Online payment',
        ),
      );
      await controller.markCancelled(record!.attemptId);

      expect(
        controller.history.first.status,
        FundraisingDonationCheckoutStatus.cancelled,
      );
      expect(await storage.getActiveAttemptId(), isNull);
    });

    test('maps timeout errors safely', () async {
      final controller = FundraisingDonationCheckoutController(
        repository: _FakeDonationRepository(
          createHandler:
              ({
                required campaignId,
                required amountMinor,
                required idempotencyKey,
                required returnUrl,
                required cancelUrl,
                required currencyCode,
              }) async {
                throw ApiClientException(
                  message: 'timeout',
                  dioExceptionType: 'connectionTimeout',
                );
              },
        ),
        storage: _InMemoryCheckoutStorage(),
        analyticsService: AnalyticsService.instance,
      );

      final record = await controller.startCheckout(
        campaignId: 19,
        campaignTitle: 'Timeout fundraiser',
        draft: const FundraisingDonationDraft(
          amountMinor: 500,
          isAnonymous: false,
          supportMessage: '',
          consentAccepted: true,
          paymentMethodLabel: 'Online payment',
        ),
      );

      expect(record, isNull);
      expect(
        controller.lastFailure?.type,
        FundraisingDonationErrorType.timeout,
      );
    });

    test('maps expired session safely', () async {
      final controller = FundraisingDonationCheckoutController(
        repository: _FakeDonationRepository(
          createHandler:
              ({
                required campaignId,
                required amountMinor,
                required idempotencyKey,
                required returnUrl,
                required cancelUrl,
                required currencyCode,
              }) async {
                throw ApiClientException(
                  message: 'expired',
                  statusCode: 401,
                  code: 'CENTRAL_TOKEN_EXPIRED',
                );
              },
        ),
        storage: _InMemoryCheckoutStorage(),
        analyticsService: AnalyticsService.instance,
      );

      final record = await controller.startCheckout(
        campaignId: 25,
        campaignTitle: 'Session fundraiser',
        draft: const FundraisingDonationDraft(
          amountMinor: 500,
          isAnonymous: false,
          supportMessage: '',
          consentAccepted: true,
          paymentMethodLabel: 'Online payment',
        ),
      );

      expect(record, isNull);
      expect(
        controller.lastFailure?.type,
        FundraisingDonationErrorType.sessionExpired,
      );
    });

    test('ignores duplicate taps while checkout is already starting', () async {
      final completer = Completer<FundraisingDonationCheckoutResponse>();
      final repository = _FakeDonationRepository(
        createHandler:
            ({
              required campaignId,
              required amountMinor,
              required idempotencyKey,
              required returnUrl,
              required cancelUrl,
              required currencyCode,
            }) {
              return completer.future;
            },
      );
      final controller = FundraisingDonationCheckoutController(
        repository: repository,
        storage: _InMemoryCheckoutStorage(),
        analyticsService: AnalyticsService.instance,
      );

      final first = controller.startCheckout(
        campaignId: 30,
        campaignTitle: 'Duplicate fundraiser',
        draft: const FundraisingDonationDraft(
          amountMinor: 300,
          isAnonymous: false,
          supportMessage: '',
          consentAccepted: true,
          paymentMethodLabel: 'Online payment',
        ),
      );
      final second = controller.startCheckout(
        campaignId: 30,
        campaignTitle: 'Duplicate fundraiser',
        draft: const FundraisingDonationDraft(
          amountMinor: 300,
          isAnonymous: false,
          supportMessage: '',
          consentAccepted: true,
          paymentMethodLabel: 'Online payment',
        ),
      );

      expect(await second, isNull);
      completer.complete(
        _response(
          status: 'PENDING',
          amountMinor: 300,
          idempotencyKey: 'duplicate-finished',
        ),
      );
      expect(await first, isNotNull);
      expect(repository.createCalls, 1);
    });
  });
}

class _FakeDonationRepository extends FundraisingRepository {
  _FakeDonationRepository({this.createHandler}) : super(ApiClient(dio: Dio()));

  final Future<FundraisingDonationCheckoutResponse> Function({
    required int campaignId,
    required int amountMinor,
    required String idempotencyKey,
    required String returnUrl,
    required String cancelUrl,
    required String currencyCode,
  })?
  createHandler;

  int createCalls = 0;

  @override
  Future<FundraisingDonationCheckoutResponse> createDonationCheckout({
    required int campaignId,
    required int amountMinor,
    required String idempotencyKey,
    required String returnUrl,
    required String cancelUrl,
    String currencyCode = 'BDT',
  }) async {
    createCalls += 1;
    return createHandler!.call(
      campaignId: campaignId,
      amountMinor: amountMinor,
      idempotencyKey: idempotencyKey,
      returnUrl: returnUrl,
      cancelUrl: cancelUrl,
      currencyCode: currencyCode,
    );
  }

  @override
  Future<FundraisingDonationCheckoutResponse> pollDonationCheckout({
    required int campaignId,
    required int amountMinor,
    required String idempotencyKey,
    required String returnUrl,
    required String cancelUrl,
    String currencyCode = 'BDT',
  }) async {
    return createHandler!.call(
      campaignId: campaignId,
      amountMinor: amountMinor,
      idempotencyKey: idempotencyKey,
      returnUrl: returnUrl,
      cancelUrl: cancelUrl,
      currencyCode: currencyCode,
    );
  }
}

class _InMemoryCheckoutStorage extends FundraisingDonationCheckoutStorage {
  final Map<String, FundraisingDonationCheckoutRecord> _records =
      <String, FundraisingDonationCheckoutRecord>{};
  String? _activeAttemptId;

  @override
  Future<List<FundraisingDonationCheckoutRecord>> loadAll() async {
    final all = _records.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  @override
  Future<FundraisingDonationCheckoutRecord?> loadByAttemptId(
    String attemptId,
  ) async {
    return _records[attemptId];
  }

  @override
  Future<void> upsert(FundraisingDonationCheckoutRecord record) async {
    _records[record.attemptId] = record;
  }

  @override
  Future<void> setActiveAttemptId(String? attemptId) async {
    _activeAttemptId = attemptId;
  }

  @override
  Future<String?> getActiveAttemptId() async => _activeAttemptId;

  @override
  Future<FundraisingDonationCheckoutRecord?> loadActiveAttempt() async {
    if (_activeAttemptId == null) return null;
    return _records[_activeAttemptId];
  }
}

FundraisingDonationCheckoutResponse _response({
  required String status,
  required int amountMinor,
  required String idempotencyKey,
}) {
  final now = DateTime.now();
  return FundraisingDonationCheckoutResponse(
    donationIntent: FundraisingDonationIntentSnapshot(
      id: 1,
      publicId: 'intent-$idempotencyKey',
      referenceId: 'FRDON-$idempotencyKey',
      status: status,
      amountMinor: amountMinor,
      currencyCode: 'BDT',
      expiresAt: now.add(const Duration(minutes: 30)),
      finalizedAt: status == 'SUCCEEDED' ? now : null,
      createdAt: now,
      updatedAt: now,
    ),
    payment: FundraisingDonationPaymentSnapshot(
      provider: 'wpa',
      redirectUrl: 'https://payments.example.com/$idempotencyKey',
      providerPaymentId: 'pay-$idempotencyKey',
      paymentAttemptId: 7,
    ),
    reused: false,
  );
}
