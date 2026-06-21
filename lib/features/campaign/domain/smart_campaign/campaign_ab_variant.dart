/// A/B test variant assignment for campaign banners.
class CampaignAbVariant {
  final String testKey;
  final String variant;
  final String slug;

  const CampaignAbVariant({
    required this.testKey,
    required this.variant,
    required this.slug,
  });

  Map<String, String> analyticsParams() => {
        'ab_test_key': testKey,
        'ab_variant': variant,
        'campaign_slug': slug,
      };
}
