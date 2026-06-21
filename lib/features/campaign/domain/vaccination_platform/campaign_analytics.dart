class CampaignAreaStat {
  final int? bdAreaId;
  final String bookingArea;
  final int totalBookings;
  final int totalCats;
  final int vaccinatedCats;

  const CampaignAreaStat({
    this.bdAreaId,
    required this.bookingArea,
    this.totalBookings = 0,
    this.totalCats = 0,
    this.vaccinatedCats = 0,
  });

  factory CampaignAreaStat.fromJson(Map<String, dynamic> json) {
    return CampaignAreaStat(
      bdAreaId: json['bdAreaId'] == null ? null : int.tryParse('${json['bdAreaId']}'),
      bookingArea: json['bookingArea']?.toString() ?? 'Unknown',
      totalBookings: json['totalBookings'] is int
          ? json['totalBookings'] as int
          : int.tryParse('${json['totalBookings']}') ?? 0,
      totalCats: json['totalCats'] is int
          ? json['totalCats'] as int
          : int.tryParse('${json['totalCats']}') ?? 0,
      vaccinatedCats: json['vaccinatedCats'] is int
          ? json['vaccinatedCats'] as int
          : int.tryParse('${json['vaccinatedCats']}') ?? 0,
    );
  }
}

class CampaignLiveAnalytics {
  final int totalBookings;
  final int vaccinatedCats;
  final int remainingSlotCapacity;
  final int participatingClinics;
  final List<CampaignAreaStat> areaStats;
  final DateTime? updatedAt;

  const CampaignLiveAnalytics({
    this.totalBookings = 0,
    this.vaccinatedCats = 0,
    this.remainingSlotCapacity = 0,
    this.participatingClinics = 0,
    this.areaStats = const [],
    this.updatedAt,
  });

  factory CampaignLiveAnalytics.fromJson(Map<String, dynamic> json) {
    final areasRaw = json['areaStats'];
    final areas = areasRaw is List
        ? areasRaw
            .whereType<Map>()
            .map((e) => CampaignAreaStat.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <CampaignAreaStat>[];

    return CampaignLiveAnalytics(
      totalBookings: json['totalBookings'] is int
          ? json['totalBookings'] as int
          : int.tryParse('${json['totalBookings']}') ?? 0,
      vaccinatedCats: json['vaccinatedCats'] is int
          ? json['vaccinatedCats'] as int
          : int.tryParse('${json['vaccinatedCats']}') ?? 0,
      remainingSlotCapacity: json['remainingSlotCapacity'] is int
          ? json['remainingSlotCapacity'] as int
          : int.tryParse('${json['remainingSlotCapacity']}') ?? 0,
      participatingClinics: json['participatingClinics'] is int
          ? json['participatingClinics'] as int
          : int.tryParse('${json['participatingClinics']}') ?? 0,
      areaStats: areas,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse('${json['updatedAt']}') : null,
    );
  }
}
