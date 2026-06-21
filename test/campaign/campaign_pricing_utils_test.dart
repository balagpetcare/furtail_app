import 'package:bpa_app/features/campaign/data/models/campaign_public_models.dart';
import 'package:bpa_app/features/campaign/presentation/utils/campaign_pricing_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computeCampaignPriceBreakdown multiplies by cat count', () {
    final campaign = PublicCampaign(
      id: 1,
      name: 'Paid',
      slug: 'paid',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 12, 31),
      pricingType: 'PAID',
      priceAmount: 200,
    );
    final breakdown = computeCampaignPriceBreakdown(campaign: campaign, catCount: 3);
    expect(breakdown.quantity, 3);
    expect(breakdown.subtotal, 600);
    expect(breakdown.total, 600);
  });

  test('free campaign returns zero total', () {
    final campaign = PublicCampaign(
      id: 1,
      name: 'Free',
      slug: 'free',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 12, 31),
      pricingType: 'FREE',
    );
    final breakdown = computeCampaignPriceBreakdown(campaign: campaign, catCount: 2);
    expect(breakdown.isFree, true);
    expect(breakdown.total, 0);
  });
}
