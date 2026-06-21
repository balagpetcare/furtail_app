/// Reusable campaign program types for BPA Smart Campaign Engine.
enum BpaCampaignType {
  vaccination('VACCINATION', 'Vaccination'),
  deworming('DEWORMING', 'Deworming'),
  sterilization('STERILIZATION', 'Sterilization'),
  healthCheckup('HEALTH_CHECKUP', 'Health Checkup'),
  adoption('ADOPTION', 'Adoption Drive');

  const BpaCampaignType(this.code, this.label);
  final String code;
  final String label;

  static BpaCampaignType fromCode(String? raw) {
    if (raw == null || raw.isEmpty) return BpaCampaignType.vaccination;
    final n = raw.trim().toUpperCase();
    for (final t in BpaCampaignType.values) {
      if (t.code == n) return t;
    }
    switch (n) {
      case 'VACCINE':
      case 'VACCINATION_CAMPAIGN':
        return BpaCampaignType.vaccination;
      case 'DEWORM':
        return BpaCampaignType.deworming;
      case 'STERILIZE':
      case 'SPAY_NEUTER':
        return BpaCampaignType.sterilization;
      case 'CHECKUP':
      case 'WELLNESS':
        return BpaCampaignType.healthCheckup;
      default:
        return BpaCampaignType.vaccination;
    }
  }
}
