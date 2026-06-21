/// Reusable campaign program types for Furtail Smart Campaign Engine.
enum FurtailCampaignType {
  vaccination('VACCINATION', 'Vaccination'),
  deworming('DEWORMING', 'Deworming'),
  sterilization('STERILIZATION', 'Sterilization'),
  healthCheckup('HEALTH_CHECKUP', 'Health Checkup'),
  adoption('ADOPTION', 'Adoption Drive');

  const FurtailCampaignType(this.code, this.label);
  final String code;
  final String label;

  static FurtailCampaignType fromCode(String? raw) {
    if (raw == null || raw.isEmpty) return FurtailCampaignType.vaccination;
    final n = raw.trim().toUpperCase();
    for (final t in FurtailCampaignType.values) {
      if (t.code == n) return t;
    }
    switch (n) {
      case 'VACCINE':
      case 'VACCINATION_CAMPAIGN':
        return FurtailCampaignType.vaccination;
      case 'DEWORM':
        return FurtailCampaignType.deworming;
      case 'STERILIZE':
      case 'SPAY_NEUTER':
        return FurtailCampaignType.sterilization;
      case 'CHECKUP':
      case 'WELLNESS':
        return FurtailCampaignType.healthCheckup;
      default:
        return FurtailCampaignType.vaccination;
    }
  }
}
