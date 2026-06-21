import 'package:furtail_app/features/campaign/data/models/campaign_public_models.dart';
import 'package:furtail_app/features/campaign/widgets/campaign_hero_banner.dart';
import 'package:furtail_app/features/campaign/widgets/campaign_mini_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PublicCampaign _sampleCampaign() {
  return PublicCampaign.fromJson({
    'id': 1,
    'name': 'Cat Flu & Rabies 2026',
    'slug': 'cat-flu-2026',
    'description': 'Official Furtail vaccination drive',
    'startDate': '2026-06-01',
    'endDate': '2026-12-31',
    'pricingType': 'PAID',
    'priceAmount': 500,
    'locations': [
      {'id': 1, 'name': 'Dhaka', 'address': 'Mirpur'},
    ],
  });
}

void main() {
  testWidgets('CampaignHeroBanner shows title and Book Now', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: CampaignHeroBanner(campaign: _sampleCampaign()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Cat Flu & Rabies 2026'), findsOneWidget);
    expect(find.text('Book Now'), findsOneWidget);
    expect(find.text('Furtail Official'), findsOneWidget);
  });

  testWidgets('CampaignMiniCard is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignMiniCard(
            campaign: _sampleCampaign(),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CampaignMiniCard));
    expect(tapped, isTrue);
  });

  testWidgets('CampaignHeroBanner CTA callback', (tester) async {
    PublicCampaign? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: CampaignHeroBanner(
                campaign: _sampleCampaign(),
                onBookNow: (c, {bookNow = false}) => selected = c,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(selected?.slug, 'cat-flu-2026');
  });
}
