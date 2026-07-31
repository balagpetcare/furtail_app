import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:furtail_app/core/config/app_config.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/services/api_client.dart';

import 'e2e_test_harness.dart';

Future<E2eTestHarness> _bootHarness(WidgetTester tester) async {
  await waitForApiReady();
  final harness = await E2eTestHarness.install(
    subject: '1',
    email: 'amina@example.com',
    displayName: 'Amina',
  );
  await launchAuthenticatedApp(tester, harness.session);
  return harness;
}

Map<String, dynamic> _mapOf(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

String _webhookSignature({
  required String provider,
  required String eventId,
  required String referenceId,
  required String status,
  required Object amountMinor,
  required String currencyCode,
  String? providerPaymentId,
  required Map<String, dynamic> payload,
}) {
  final ordered = <String, dynamic>{};
  final keys = payload.keys.map((key) => key.toString()).toList()..sort();
  for (final key in keys) {
    ordered[key] = payload[key];
  }
  final body = jsonEncode(ordered);
  return Hmac(sha256, utf8.encode('local-dev-fundraising-secret'))
      .convert(
        utf8.encode(
          [
            provider,
            eventId,
            referenceId,
            status,
            amountMinor.toString(),
            currencyCode,
            providerPaymentId ?? '',
            body,
          ].join('|'),
        ),
      )
      .toString();
}

Future<Map<String, dynamic>> _webhook(
  ApiClient api,
  Map<String, dynamic> payload,
) async {
  final signature = _webhookSignature(
    provider: payload['provider'].toString(),
    eventId: payload['eventId'].toString(),
    referenceId: payload['referenceId'].toString(),
    status: payload['status'].toString(),
    amountMinor: payload['amountMinor'],
    currencyCode: payload['currencyCode'].toString(),
    providerPaymentId: payload['providerPaymentId']?.toString(),
    payload: payload,
  );
  return _mapOf(
    await api.post(
      '${AppConfig.apiV1}/fundraising/payments/webhooks/provider',
      payload,
      auth: false,
      headers: {'X-Furtail-Signature': signature},
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fundraising flow covers draft restore, publish, public feed/detail, share link, protected draft edits, donation checkout, callback verification, duplicate callback prevention, and receipt',
    (tester) async {
      final harness = await _bootHarness(tester);
      try {
        final api = ApiClient();
        final fundraising = FundraisingRepository(ApiClient());

        final imageUpload = await api.multipartPostTyped<Map<String, dynamic>>(
          url: '${AppConfig.apiV1}/media/upload',
          files: [
            ApiMultipartFilePart(
              fieldName: 'file',
              file: File(harness.artifacts.imagePath),
            ),
          ],
          fields: const <String, String>{
            'contentType': 'fundraising',
            'contentId': 'fundraising-media',
            'idempotencyKey': 'fundraising-image-1',
          },
          parse: (decoded) => _mapOf(decoded)['data'] as Map<String, dynamic>,
        );

        await fundraising.updateMyAccount({
          'accountType': 'INDIVIDUAL',
          'presentAddress': 'Dhaka',
          'permanentAddress': 'Dhaka',
          'area': 'Dhaka',
          'countryCode': 'BD',
          'countryName': 'Bangladesh',
          'stateName': 'Dhaka',
          'cityName': 'Dhaka',
          'addressLine': 'Dhaka',
        });
        final accountBeforeSubmit = await fundraising.fetchMyAccount();
        final uploadedMediaId = (imageUpload['id'] as num).toInt();
        final hasVerificationDocument = accountBeforeSubmit?.documents.any(
          (document) => (document.mediaId ?? -1) == uploadedMediaId,
        );
        if (hasVerificationDocument != true) {
          await fundraising.addDocument(
            title: 'National ID',
            mediaId: uploadedMediaId,
          );
        }
        await fundraising.submitMyAccount();

        final draftTitle = 'E2E ${uniqueDataSuffix('fundraiser')}';
        final draft = await fundraising.createDraft(
          payload: {
            'title': draftTitle,
            'caption': 'Need urgent support for treatment',
            'category': 'PET_HEALTH',
            'fundingMode': 'ONE_TIME',
            'currencyCode': 'BDT',
            'targetAmountMinor': 125000,
            'beneficiaryType': 'PET',
            'beneficiaryName': 'Luna',
            'locationText': 'Dhaka, Bangladesh',
            'deadline': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
            'mediaIds': [(imageUpload['id'] as num).toInt()],
          },
        );
        expect(draft.status.toUpperCase(), 'DRAFT');

        final restoredDraft = await fundraising.fetchDraft(draft.id.toString());
        expect(restoredDraft.id, draft.id);

        final updatedDraft = await fundraising.updateDraft(
          draftId: draft.id.toString(),
          payload: {
            'caption': 'Updated treatment support story',
            'locationText': 'Dhaka, Bangladesh',
          },
        );
        expect(updatedDraft.caption, 'Updated treatment support story');

        final submittedDraft = await fundraising.submitDraft(
          draftId: draft.id.toString(),
          idempotencyKey: 'fundraising-submit-${uniqueDataSuffix('submit')}',
        );
        expect(submittedDraft.status.toUpperCase(), 'SUBMITTED');

        final campaigns = await fundraising.fetchMyCampaigns(limit: 100);
        final campaign = campaigns.firstWhere(
          (item) => item.title == draftTitle,
          orElse: () => campaigns.first,
        );
        expect(campaign.title, draftTitle);

        final published = _mapOf(
          await api.post(
            '${AppConfig.apiV1}/fundraising/campaigns/${campaign.id}/publish',
            const <String, dynamic>{},
          ),
        );
        expect((published['data'] as Map)['status'], 'ACTIVE');

        final feed = await fundraising.fetchFeed(limit: 50);
        final feedCampaign = feed.firstWhere(
          (item) => item.id == campaign.id,
          orElse: () => feed.first,
        );
        expect(feedCampaign.id, campaign.id);

        final detail = await fundraising.fetchCampaign(campaign.id);
        expect(detail.id, campaign.id);
        expect(detail.title, draftTitle);

        final checkout = await fundraising.createDonationCheckout(
          campaignId: campaign.id,
          amountMinor: 1500,
          idempotencyKey: 'donation-${uniqueDataSuffix('checkout')}',
          returnUrl: 'furtail://fundraising/checkout/success',
          cancelUrl: 'furtail://fundraising/checkout/cancel',
        );
        expect(checkout.payment?.redirectUrl, isNotNull);
        final referenceId = checkout.donationIntent.referenceId;
        expect(referenceId, isNotEmpty);

        final statusBefore = _mapOf(
          await api.get(
            '${AppConfig.apiV1}/fundraising/payments/$referenceId/status',
          ),
        );
        expect(statusBefore['data'], isNotNull);

        final successPayload = {
          'provider': 'mockpay',
          'eventId': 'evt-success-${uniqueDataSuffix('funding')}',
          'referenceId': referenceId,
          'status': 'SUCCEEDED',
          'amountMinor': 1500,
          'currencyCode': 'BDT',
          'providerPaymentId': 'provider-${uniqueDataSuffix('payment')}',
        };
        final success = await _webhook(api, successPayload);
        expect(
          (success['data'] as Map)['donationIntent']['status'],
          'SUCCEEDED',
        );
        expect((success['data'] as Map)['receipt'], isNotNull);

        final duplicate = await _webhook(api, successPayload);
        expect((duplicate['data'] as Map)['duplicate'], isTrue);

        final donationRecords = await fundraising.listDonations(
          campaignId: campaign.id,
        );
        expect(donationRecords.length, 1);

        final failedCheckout = await fundraising.createDonationCheckout(
          campaignId: campaign.id,
          amountMinor: 2000,
          idempotencyKey: 'donation-${uniqueDataSuffix('failed')}',
          returnUrl: 'furtail://fundraising/checkout/success',
          cancelUrl: 'furtail://fundraising/checkout/cancel',
        );
        final failedPayload = {
          'provider': 'mockpay',
          'eventId': 'evt-failed-${uniqueDataSuffix('funding')}',
          'referenceId': failedCheckout.donationIntent.referenceId,
          'status': 'FAILED',
          'amountMinor': 2000,
          'currencyCode': 'BDT',
          'providerPaymentId': 'provider-${uniqueDataSuffix('payment')}',
        };
        final failed = await _webhook(api, failedPayload);
        expect((failed['data'] as Map)['status'], 'FAILED');

        final cancelledCheckout = await fundraising.createDonationCheckout(
          campaignId: campaign.id,
          amountMinor: 3000,
          idempotencyKey: 'donation-${uniqueDataSuffix('cancelled')}',
          returnUrl: 'furtail://fundraising/checkout/success',
          cancelUrl: 'furtail://fundraising/checkout/cancel',
        );
        final cancelledPayload = {
          'provider': 'mockpay',
          'eventId': 'evt-cancel-${uniqueDataSuffix('funding')}',
          'referenceId': cancelledCheckout.donationIntent.referenceId,
          'status': 'CANCELLED',
          'amountMinor': 3000,
          'currencyCode': 'BDT',
          'providerPaymentId': 'provider-${uniqueDataSuffix('payment')}',
        };
        final cancelled = await _webhook(api, cancelledPayload);
        expect((cancelled['data'] as Map)['status'], 'CANCELLED');

        final ownerUpdated = await fundraising.updateCampaign(
          campaignId: campaign.id,
          title: '$draftTitle updated',
        );
        expect(ownerUpdated.title, '$draftTitle updated');

        final ownerSession = harness.session;
        final foreignSession = E2eTestSession(
          subject: '2',
          email: 'zara@example.com',
          displayName: 'Zara',
        );
        foreignSession.seed();
        try {
          try {
            await FundraisingRepository(ApiClient()).updateDraft(
              draftId: draft.id.toString(),
              payload: {'caption': 'Should not save'},
            );
            fail('Expected the draft edit to be denied for a non-owner.');
          } on ApiClientException catch (error) {
            expect(error.statusCode, 403);
          }
        } finally {
          ownerSession.seed();
        }

        await fundraising.deleteCampaign(campaignId: campaign.id);
      } finally {
        await harness.dispose();
      }
    },
  );
}
