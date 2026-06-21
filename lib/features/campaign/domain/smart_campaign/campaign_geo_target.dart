/// Geo targeting rules attached to a campaign (from admin metadata).
class CampaignGeoTarget {
  final List<String> cities;
  final List<String> districts;
  final List<String> serviceAreas;

  const CampaignGeoTarget({
    this.cities = const [],
    this.districts = const [],
    this.serviceAreas = const [],
  });

  bool get isEmpty => cities.isEmpty && districts.isEmpty && serviceAreas.isEmpty;

  factory CampaignGeoTarget.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CampaignGeoTarget();
    List<String> list(dynamic v) {
      if (v is! List) return const [];
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    return CampaignGeoTarget(
      cities: list(json['cities']),
      districts: list(json['districts']),
      serviceAreas: list(json['serviceAreas'] ?? json['areas']),
    );
  }

  Map<String, dynamic> toJson() => {
        'cities': cities,
        'districts': districts,
        'serviceAreas': serviceAreas,
      };
}

/// User location preferences for geo-filtered notifications.
class UserGeoPreferences {
  final String? city;
  final String? district;
  final String? serviceArea;
  final int? divisionId;
  final int? districtId;
  final int? upazilaId;

  const UserGeoPreferences({
    this.city,
    this.district,
    this.serviceArea,
    this.divisionId,
    this.districtId,
    this.upazilaId,
  });

  bool get isConfigured =>
      (city != null && city!.isNotEmpty) ||
      (district != null && district!.isNotEmpty) ||
      (serviceArea != null && serviceArea!.isNotEmpty);

  Map<String, dynamic> toJson() => {
        'city': city,
        'district': district,
        'serviceArea': serviceArea,
        'divisionId': divisionId,
        'districtId': districtId,
        'upazilaId': upazilaId,
      };

  factory UserGeoPreferences.fromJson(Map<String, dynamic> json) {
    return UserGeoPreferences(
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      serviceArea: json['serviceArea']?.toString(),
      divisionId: json['divisionId'] == null ? null : int.tryParse('${json['divisionId']}'),
      districtId: json['districtId'] == null ? null : int.tryParse('${json['districtId']}'),
      upazilaId: json['upazilaId'] == null ? null : int.tryParse('${json['upazilaId']}'),
    );
  }
}
