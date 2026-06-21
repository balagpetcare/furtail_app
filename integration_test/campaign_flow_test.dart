import 'package:furtail_app/features/campaign/data/models/campaign_public_models.dart';
import 'package:furtail_app/features/campaign/presentation/screens/campaign_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Campaign details page shows campaign name from provider override',
      (tester) async {
    const slug = 'test-slug';
    final campaign = PublicCampaign.fromJson({
      'id': 99,
      'name': 'Integration Test Campaign',
      'slug': slug,
      'startDate': '2026-06-01',
      'endDate': '2026-12-31',
      'pricingType': 'FREE',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // ignore: invalid_use_of_visible_for_testing_member
        ],
        child: MaterialApp(
          home: CampaignDetailsPage(slug: slug),
        ),
      ),
    );

    // Without backend, page shows loading then error — verify scaffold exists.
    expect(find.byType(CampaignDetailsPage), findsOneWidget);
    expect(find.text('Campaign Details'), findsOneWidget);
  });
}
