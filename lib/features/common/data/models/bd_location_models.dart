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
      divisionId: (j['divisionId'] as num).toInt(),
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
      districtId: (j['districtId'] as num).toInt(),
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
  final int? upazilaId;
  final int? districtId;
  final int? parentId;

  const BdArea({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
    required this.type,
    this.upazilaId,
    this.districtId,
    this.parentId,
  });

  factory BdArea.fromJson(Map<String, dynamic> j) {
    return BdArea(
      id: (j['id'] as num).toInt(),
      code: (j['code'] ?? '').toString(),
      nameEn: (j['nameEn'] ?? '').toString(),
      nameBn: j['nameBn']?.toString(),
      type: (j['type'] ?? '').toString(),
      upazilaId: (j['upazilaId'] as num?)?.toInt(),
      districtId: (j['districtId'] as num?)?.toInt(),
      parentId: (j['parentId'] as num?)?.toInt(),
    );
  }

  String display({bool bn = false}) {
    final b = (nameBn ?? '').trim();
    return (bn && b.isNotEmpty) ? b : nameEn;
  }
}
