import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:furtail_app/core/auth/auth_interceptor.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/config/app_config.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/services/api_client.dart';

import 'e2e_test_harness.dart';

Map<String, dynamic> _mapOf(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'auth session refreshes once, replays once, preserves 403, and clears on definitive refresh failure',
    (tester) async {
      final harness = await _bootHarness(tester);
      final cleanup = E2eCleanupBag();
      try {
        final api = ApiClient();

        final me = _mapOf(await api.get('${AppConfig.apiV1}/auth/me'));
        final meUser = _mapOf(me['data'] as Map)['user'] as Map;
        final authMeId = (meUser['id'] as num).toInt();
        expect(authMeId, greaterThan(0));

        final profile = _mapOf(await api.get('${AppConfig.apiV1}/user/me'));
        final profileUser = _mapOf(profile['data'] as Map);
        expect((profileUser['id'] as num).toInt(), authMeId);

        harness.session.expireAccessToken();
        final refreshResults = await Future.wait([
          api.get('${AppConfig.apiV1}/auth/me'),
          api.get('${AppConfig.apiV1}/posts/feed?limit=1'),
        ]);
        expect(harness.session.refreshCount, 1);
        final refreshedMe = _mapOf(refreshResults[0]);
        expect(
          ((_mapOf(refreshedMe['data'] as Map))['user'] as Map)['id'],
          authMeId,
        );

        harness.session.expireAccessToken();
        final uploadResult = await api.multipartPostTyped<Map<String, dynamic>>(
          url: '${AppConfig.apiV1}/media/upload',
          files: [
            ApiMultipartFilePart(
              fieldName: 'file',
              file: File(harness.artifacts.imagePath),
            ),
          ],
          fields: const <String, String>{
            'contentType': 'auth-session',
            'contentId': 'auth-session-smoke',
            'idempotencyKey': 'auth-session-upload-1',
          },
          parse: (decoded) =>
              Map<String, dynamic>.from((decoded as Map)['data'] as Map),
        );
        expect(harness.session.refreshCount, 2);
        expect((uploadResult['id'] as num).toInt(), greaterThan(0));

        final fundraiserFeed = await FundraisingRepository(
          ApiClient(),
        ).fetchFeed(limit: 20);
        final foreignCampaign = fundraiserFeed.firstWhere(
          (campaign) => campaign.author.id != authMeId,
          orElse: () => fundraiserFeed.first,
        );
        expect(foreignCampaign.author.id, isNot(authMeId));

        final fundraising = FundraisingRepository(ApiClient());
        final previousAccessToken = await SecureStorageService().accessToken;
        expect(previousAccessToken, isNotNull);

        try {
          await fundraising.updateCampaign(
            campaignId: foreignCampaign.id,
            title: 'Forbidden change ${uniqueDataSuffix('forbidden')}',
          );
          fail('Expected a 403 when editing a non-owned fundraiser.');
        } on ApiClientException catch (error) {
          expect(error.statusCode, 403);
          expect(error.code, anyOf(isNull, isNot(equals(''))));
        }

        expect(await SecureStorageService().accessToken, isNotNull);
        expect(await SecureStorageService().refreshToken, isNotNull);

        final refreshFailureCallbackCount = <int>[0];
        final failedInterceptor = AuthInterceptor(
          secureStorage: SecureStorageService(),
          centralAuthApi: CentralAuthApi(),
          onSessionExpired: () {
            refreshFailureCallbackCount[0] += 1;
          },
        );
        final failingClient = ApiClient(authInterceptor: failedInterceptor);

        harness.session.expireAccessToken();
        CentralAuthApi.installRefreshTokenOverride((_) async {
          throw CentralAuthException(
            message: 'Refresh token revoked for test.',
            statusCode: 401,
            code: 'TOKEN_REVOKED',
          );
        });

        try {
          await failingClient.get('${AppConfig.apiV1}/posts/feed?limit=1');
          fail('Expected refresh failure to propagate a 401.');
        } on ApiClientException catch (error) {
          expect(error.statusCode, 401);
          expect(error.code, anyOf('CENTRAL_TOKEN_EXPIRED', 'TOKEN_REVOKED'));
        }

        expect(refreshFailureCallbackCount.single, 1);
        expect(await SecureStorageService().accessToken, isNull);
        expect(await SecureStorageService().refreshToken, isNull);
      } finally {
        await cleanup.run();
        await harness.dispose();
      }
    },
  );
}
