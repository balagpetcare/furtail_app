class BdDivision {
  final int id;
  final String code;
  final String nameEn;
  final String? nameBn;

  const BdDivision({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
  });

  factory BdDivision.fromJson(Map<String, dynamic> j) {
    return BdDivision(
      id: (j['id'] as num).toInt(),
      code: (j['code'] ?? '').toString(),
      nameEn: (j['nameEn'] ?? '').toString(),
      nameBn: j['nameBn']?.toString(),
    );
  }

  String display({bool bn = false}) {
    final b = (nameBn ?? '').trim();
    return (bn && b.isNotEmpty) ? b : nameEn;
  }
}

class BdDistrict {
  final int id;
  final String code;
  final String nameEn;
  final String? nameBn;
  final int divisionId;

  const BdDistrict({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
    required this.divisionId,
  });

  factory BdDistrict.fromJson(Map<String, dynamic> j) {
    return BdDistrict(
      id: (j['id'] as num).toInt(),
      code: (j['code'] ?? '').toString(),
      nameEn: (j['nameEn'] ?? '').toString(),
      nameBn: j['nameBn']?.toString(),
      divisionId: (j['divisionId'] as num?)?.toInt() ?? 0,
    );
  }

  String display({bool bn = false}) {
    final b = (nameBn ?? '').trim();
    return (bn && b.isNotEmpty) ? b : nameEn;
  }
}

class BdUpazila {
  final int id;
  final String code;
  final String nameEn;
  final String? nameBn;
  final int districtId;

  const BdUpazila({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
    required this.districtId,
  });

  factory BdUpazila.fromJson(Map<String, dynamic> j) {
    return BdUpazila(
      id: (j['id'] as num).toInt(),
      code: (j['code'] ?? '').toString(),
      nameEn: (j['nameEn'] ?? '').toString(),
      nameBn: j['nameBn']?.toString(),
      districtId: (j['districtId'] as num?)?.toInt() ?? 0,
    );
  }

  String display({bool bn = false}) {
    final b = (nameBn ?? '').trim();
    return (bn && b.isNotEmpty) ? b : nameEn;
  }
}

class BdUnion {
  final int id;
  final String code;
  final String nameEn;
  final String? nameBn;
  final int upazilaId;

  const BdUnion({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
    required this.upazilaId,
  });

  factory BdUnion.fromJson(Map<String, dynamic> j) {
    return BdUnion(
      id: (j['id'] as num).toInt(),
      code: (j['code'] ?? '').toString(),
      nameEn: (j['nameEn'] ?? '').toString(),
      nameBn: j['nameBn']?.toString(),
      upazilaId: (j['upazilaId'] as num?)?.toInt() ?? 0,
    );
  }

  String display({bool bn = false}) {
    final b = (nameBn ?? '').trim();
    return (bn && b.isNotEmpty) ? b : nameEn;
  }
}

class BdArea {
  final int id;
  final String code;
  final String nameEn;
  final String? nameBn;
  final String type;
  final String reviewStatus;
  final String currentValidity;
  final Object? provenance;
  final int? unionId;
  final int? upazilaId;
  final int? districtId;
  final int? parentId;
  final bool? isLegacyFlag;
  final bool? isCurrentSelectableFlag;
  final String? reviewMessage;

  const BdArea({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
    required this.type,
    this.reviewStatus = 'CURRENT_VERIFIED',
    this.currentValidity = 'CURRENT_VERIFIED',
    this.provenance,
    this.unionId,
    this.upazilaId,
    this.districtId,
    this.parentId,
    this.isLegacyFlag,
    this.isCurrentSelectableFlag,
    this.reviewMessage,
  });

  factory BdArea.fromJson(Map<String, dynamic> j) {
    return BdArea(
      id: (j['id'] as num).toInt(),
      code: (j['code'] ?? '').toString(),
      nameEn: (j['nameEn'] ?? '').toString(),
      nameBn: j['nameBn']?.toString(),
      type: (j['type'] ?? '').toString(),
      reviewStatus: (j['reviewStatus'] ?? 'CURRENT_VERIFIED').toString(),
      currentValidity: (j['currentValidity'] ?? 'CURRENT_VERIFIED').toString(),
      provenance: j['provenance'],
      unionId: (j['unionId'] as num?)?.toInt(),
      upazilaId: (j['upazilaId'] as num?)?.toInt(),
      districtId: (j['districtId'] as num?)?.toInt(),
      parentId: (j['parentId'] as num?)?.toInt(),
      isLegacyFlag: j['isLegacy'] as bool?,
      isCurrentSelectableFlag: j['isCurrentSelectable'] as bool?,
      reviewMessage: j['reviewMessage']?.toString(),
    );
  }

  bool get isLegacy => isLegacyFlag ?? (currentValidity != 'CURRENT_VERIFIED');

  bool get isSelectableForNewSelection =>
      isCurrentSelectableFlag ??
      (currentValidity == 'CURRENT_VERIFIED' ||
          currentValidity == 'PARTIAL_CURRENT');

  /// True for the urban City Corporation -> Zone -> Ward branch (never
  /// linked to a rural union/upazila directly).
  bool get isUrban =>
      type == 'CITY_CORPORATION' ||
      type == 'ZONE' ||
      (type == 'WARD' && unionId == null);

  String display({bool bn = false}) {
    final b = (nameBn ?? '').trim();
    return (bn && b.isNotEmpty) ? b : nameEn;
  }
}
