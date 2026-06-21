import 'bpa_campaign_type.dart';
import 'campaign_geo_target.dart';
import 'campaign_priority.dart';

/// Type-agnostic smart campaign configuration (reusable across program types).
class SmartCampaignConfig {
  final BpaCampaignType campaignType;
  final CampaignPriority priority;
  final CampaignGeoTarget geoTarget;
  final String? abTestKey;
  final List<String> abVariants;
  final bool countdownEnabled;

  const SmartCampaignConfig({
    this.campaignType = BpaCampaignType.vaccination,
    this.priority = CampaignPriority.medium,
    this.geoTarget = const CampaignGeoTarget(),
    this.abTestKey,
    this.abVariants = const ['A', 'B'],
    this.countdownEnabled = false,
  });

  factory SmartCampaignConfig.fromMetadata(dynamic metadataJson) {
    if (metadataJson is! Map) {
      return const SmartCampaignConfig();
    }
    final mobile = metadataJson['mobile'];
    final root = mobile is Map ? Map<String, dynamic>.from(mobile) : metadataJson;
    final geoRaw = root['geoTargets'] ?? root['geoTarget'];
    final variantsRaw = root['abVariants'];

    return SmartCampaignConfig(
      campaignType: BpaCampaignType.fromCode(
        root['campaignType']?.toString() ?? metadataJson['campaignType']?.toString(),
      ),
      priority: CampaignPriority.fromCode(root['priority']?.toString()),
      geoTarget: geoRaw is Map
          ? CampaignGeoTarget.fromJson(Map<String, dynamic>.from(geoRaw))
          : const CampaignGeoTarget(),
      abTestKey: root['abTestKey']?.toString(),
      abVariants: variantsRaw is List
          ? variantsRaw.map((e) => e.toString()).toList()
          : const ['A', 'B'],
      countdownEnabled: root['countdownEnabled'] == true ||
          metadataJson['countdownEnabled'] == true,
    );
  }
}
