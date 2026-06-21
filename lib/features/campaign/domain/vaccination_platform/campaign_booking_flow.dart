/// Wizard steps for production vaccination booking (parity with web).
enum CampaignBookingStep {
  location,
  cats,
  contact,
  review,
  success,
}

class DhakaCityCorporation {
  final int id;
  final String code;
  final String nameEn;
  final String? nameBn;

  const DhakaCityCorporation({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
  });

  factory DhakaCityCorporation.fromJson(Map<String, dynamic> json) {
    return DhakaCityCorporation(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      code: json['code']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      nameBn: json['nameBn']?.toString(),
    );
  }

  String get displayLabel {
    if (code == 'DNCC') return 'Dhaka North (DNCC)';
    if (code == 'DSCC') return 'Dhaka South (DSCC)';
    return nameEn;
  }
}

class DhakaBookingArea {
  final int id;
  final String code;
  final String nameEn;
  final String? nameBn;

  const DhakaBookingArea({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameBn,
  });

  factory DhakaBookingArea.fromJson(Map<String, dynamic> json) {
    return DhakaBookingArea(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      code: json['code']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      nameBn: json['nameBn']?.toString(),
    );
  }
}
