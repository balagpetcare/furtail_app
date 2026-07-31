/// Canonical animal type/species model — never hardcode this list in
/// Flutter; always resolve it from `AnimalTaxonomyRepository`.
class AnimalTypeModel {
  final int id;
  final String? code;
  final String name;
  final String? nameBn;
  final String? icon;
  final String? scientificName;
  final int displayOrder;

  const AnimalTypeModel({
    required this.id,
    this.code,
    required this.name,
    this.nameBn,
    this.icon,
    this.scientificName,
    this.displayOrder = 0,
  });

  factory AnimalTypeModel.fromJson(Map<String, dynamic> j) {
    return AnimalTypeModel(
      id: (j['id'] as num).toInt(),
      code: j['code']?.toString(),
      name: (j['name'] ?? '').toString(),
      nameBn: j['nameBn']?.toString(),
      icon: j['icon']?.toString(),
      scientificName: j['scientificName']?.toString(),
      displayOrder: (j['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  String display({bool bn = false}) {
    final b = (nameBn ?? '').trim();
    return (bn && b.isNotEmpty) ? b : name;
  }
}

/// Canonical breed model, always scoped to a species (`animalTypeId`).
/// `isLocal`/`isMixed`/`isUnknown`/`isOther` identify the four safe
/// non-specific choices every species offers.
class BreedModel {
  final int id;
  final String? code;
  final String name;
  final String? nameBn;
  final int animalTypeId;
  final List<String> aliasNames;
  final bool isMixed;
  final bool isOther;
  final bool isLocal;
  final bool isUnknown;
  final int displayOrder;

  const BreedModel({
    required this.id,
    this.code,
    required this.name,
    this.nameBn,
    required this.animalTypeId,
    this.aliasNames = const [],
    this.isMixed = false,
    this.isOther = false,
    this.isLocal = false,
    this.isUnknown = false,
    this.displayOrder = 0,
  });

  factory BreedModel.fromJson(Map<String, dynamic> j) {
    return BreedModel(
      id: (j['id'] as num).toInt(),
      code: j['code']?.toString(),
      name: (j['name'] ?? '').toString(),
      nameBn: j['nameBn']?.toString(),
      animalTypeId: (j['animalTypeId'] as num).toInt(),
      aliasNames:
          (j['aliasNames'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      isMixed: j['isMixed'] == true,
      isOther: j['isOther'] == true,
      isLocal: j['isLocal'] == true,
      isUnknown: j['isUnknown'] == true,
      displayOrder: (j['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  /// True for the four safe non-specific choices (Local/Indigenous, Mixed
  /// breed, Unknown, Other) as opposed to a specific named breed.
  bool get isSafeNonSpecificChoice =>
      isMixed || isOther || isLocal || isUnknown;

  String display({bool bn = false}) {
    final b = (nameBn ?? '').trim();
    return (bn && b.isNotEmpty) ? b : name;
  }
}
