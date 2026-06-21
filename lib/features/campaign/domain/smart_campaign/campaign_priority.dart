/// Homepage placement priority — HIGH always ranks first.
enum CampaignPriority {
  high('HIGH', 0),
  medium('MEDIUM', 1),
  low('LOW', 2);

  const CampaignPriority(this.code, this.sortOrder);
  final String code;
  final int sortOrder;

  static CampaignPriority fromCode(String? raw) {
    if (raw == null || raw.isEmpty) return CampaignPriority.medium;
    final n = raw.trim().toUpperCase();
    for (final p in CampaignPriority.values) {
      if (p.code == n) return p;
    }
    return CampaignPriority.medium;
  }
}
