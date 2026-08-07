import 'package:furtail_app/core/media/media_url.dart';

class PetFamilyMemberModel {
  final int id;
  final String relation;
  final String name;
  final String? avatarUrl;

  const PetFamilyMemberModel({
    required this.id,
    required this.relation,
    required this.name,
    this.avatarUrl,
  });

  factory PetFamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return PetFamilyMemberModel(
      id: _int(json["id"]) ?? 0,
      relation: (json["relation"] ?? "OTHER").toString(),
      name: (json["name"] ?? "").toString(),
      avatarUrl: _normalizedUrl(json["avatarUrl"]?.toString()),
    );
  }
}

class PetProfileModel {
  final int id;
  final String name;
  final String? photoUrl;
  final int? ageYears;
  final String? gender;
  final String? breed;
  final double? weightKg;
  final bool vaccinated;
  final DateTime? nextDueDate;
  final int pawPoints;
  final String? tier;
  final List<PetFamilyMemberModel> family;

  const PetProfileModel({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.ageYears,
    required this.gender,
    required this.breed,
    required this.weightKg,
    required this.vaccinated,
    required this.nextDueDate,
    required this.pawPoints,
    required this.tier,
    required this.family,
  });

  factory PetProfileModel.fromJson(Map<String, dynamic> json) {
    final health = (json["healthStatus"] is Map)
        ? (json["healthStatus"] as Map)
        : {};
    final familyList = (json["familyMembers"] is List)
        ? (json["familyMembers"] as List)
        : const [];

    return PetProfileModel(
      id: _int(json["id"]) ?? 0,
      name: (json["name"] ?? "").toString(),
      photoUrl: _normalizedUrl(json["photoUrl"]?.toString()),
      ageYears: _int(json["ageYears"]),
      gender: json["gender"]?.toString(),
      breed: json["breed"]?.toString(),
      weightKg: json["weightKg"] == null
          ? null
          : double.tryParse(json["weightKg"].toString()),
      vaccinated: (health["vaccinated"] ?? false) == true,
      nextDueDate: health["nextDueDate"] == null
          ? null
          : DateTime.tryParse(health["nextDueDate"].toString()),
      pawPoints: (json["pawPoints"] ?? 0) is num
          ? (json["pawPoints"] as num).toInt()
          : 0,
      tier: json["tier"]?.toString(),
      family: familyList
          .whereType<Map>()
          .map((e) => PetFamilyMemberModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

int? _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _normalizedUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final normalized = MediaUrl.normalize(value).trim();
  return normalized.isEmpty ? null : normalized;
}
