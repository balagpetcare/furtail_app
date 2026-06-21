class CampaignBookingDraft {
  final String slug;
  final int step;
  final List<int> selectedPetIds;
  final int catCount;
  final String cityCorporationCode;
  final String cityCorporationName;
  final int? bdAreaId;
  final String bookingArea;
  final int? locationId;
  final int? slotId;
  final String? slotDate;
  final String phone;
  final String alternatePhone;
  final String ownerName;
  final String? couponCode;
  final String? paymentMethod;

  const CampaignBookingDraft({
    required this.slug,
    this.step = 0,
    this.selectedPetIds = const [],
    this.catCount = 1,
    this.cityCorporationCode = '',
    this.cityCorporationName = '',
    this.bdAreaId,
    this.bookingArea = '',
    this.locationId,
    this.slotId,
    this.slotDate,
    this.phone = '',
    this.alternatePhone = '',
    this.ownerName = '',
    this.couponCode,
    this.paymentMethod,
  });

  bool get hasLocationSelection =>
      cityCorporationCode.isNotEmpty && bdAreaId != null && bookingArea.isNotEmpty;

  CampaignBookingDraft copyWith({
    int? step,
    List<int>? selectedPetIds,
    int? catCount,
    String? cityCorporationCode,
    String? cityCorporationName,
    int? bdAreaId,
    String? bookingArea,
    int? locationId,
    int? slotId,
    String? slotDate,
    String? phone,
    String? alternatePhone,
    String? ownerName,
    String? couponCode,
    String? paymentMethod,
    bool clearBdArea = false,
  }) {
    return CampaignBookingDraft(
      slug: slug,
      step: step ?? this.step,
      selectedPetIds: selectedPetIds ?? this.selectedPetIds,
      catCount: catCount ?? this.catCount,
      cityCorporationCode: cityCorporationCode ?? this.cityCorporationCode,
      cityCorporationName: cityCorporationName ?? this.cityCorporationName,
      bdAreaId: clearBdArea ? null : (bdAreaId ?? this.bdAreaId),
      bookingArea: bookingArea ?? this.bookingArea,
      locationId: locationId ?? this.locationId,
      slotId: slotId ?? this.slotId,
      slotDate: slotDate ?? this.slotDate,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      ownerName: ownerName ?? this.ownerName,
      couponCode: couponCode ?? this.couponCode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'step': step,
        'selectedPetIds': selectedPetIds,
        'catCount': catCount,
        'cityCorporationCode': cityCorporationCode,
        'cityCorporationName': cityCorporationName,
        'bdAreaId': bdAreaId,
        'bookingArea': bookingArea,
        'locationId': locationId,
        'slotId': slotId,
        'slotDate': slotDate,
        'phone': phone,
        'alternatePhone': alternatePhone,
        'ownerName': ownerName,
        'couponCode': couponCode,
        'paymentMethod': paymentMethod,
      };

  factory CampaignBookingDraft.fromJson(Map<String, dynamic> json) {
    final petsRaw = json['selectedPetIds'];
    return CampaignBookingDraft(
      slug: json['slug']?.toString() ?? '',
      step: json['step'] is int ? json['step'] as int : int.tryParse('${json['step']}') ?? 0,
      selectedPetIds: petsRaw is List
          ? petsRaw.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toList()
          : const [],
      catCount: json['catCount'] is int
          ? json['catCount'] as int
          : int.tryParse('${json['catCount']}') ?? 1,
      cityCorporationCode: json['cityCorporationCode']?.toString() ?? '',
      cityCorporationName: json['cityCorporationName']?.toString() ?? '',
      bdAreaId: json['bdAreaId'] == null ? null : int.tryParse('${json['bdAreaId']}'),
      bookingArea: json['bookingArea']?.toString() ?? '',
      locationId: json['locationId'] == null ? null : int.tryParse('${json['locationId']}'),
      slotId: json['slotId'] == null ? null : int.tryParse('${json['slotId']}'),
      slotDate: json['slotDate']?.toString(),
      phone: json['phone']?.toString() ?? '',
      alternatePhone: json['alternatePhone']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      couponCode: json['couponCode']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
    );
  }
}
