class CampaignLinkSummary {
  final bool hasUnlinkedRecords;
  final int unlinkedBookings;
  final int linkedBookings;
  final int vaccinations;
  final String? phone;

  const CampaignLinkSummary({
    required this.hasUnlinkedRecords,
    required this.unlinkedBookings,
    required this.linkedBookings,
    required this.vaccinations,
    this.phone,
  });

  factory CampaignLinkSummary.fromJson(Map<String, dynamic> json) {
    return CampaignLinkSummary(
      hasUnlinkedRecords: json['hasUnlinkedRecords'] == true,
      unlinkedBookings: campaignJsonInt(json['unlinkedBookings']),
      linkedBookings: campaignJsonInt(json['linkedBookings']),
      vaccinations: campaignJsonInt(json['vaccinations']),
      phone: json['phone']?.toString(),
    );
  }
}

class CampaignBookingPet {
  final int id;
  final String name;
  final String vaccinationStatus;
  final String? certificateToken;

  const CampaignBookingPet({
    required this.id,
    required this.name,
    required this.vaccinationStatus,
    this.certificateToken,
  });

  factory CampaignBookingPet.fromJson(Map<String, dynamic> json) {
    return CampaignBookingPet(
      id: campaignJsonInt(json['id']),
      name: json['name']?.toString() ?? 'Pet',
      vaccinationStatus: json['vaccinationStatus']?.toString() ?? 'PENDING',
      certificateToken: json['certificateToken']?.toString(),
    );
  }
}

class CampaignBooking {
  final int id;
  final String bookingRef;
  final String? qrToken;
  final String status;
  final DateTime? bookingDate;
  final String? campaignName;
  final String? locationName;
  final String? locationAddress;
  final String? slotStart;
  final String? slotEnd;
  final String ownerName;
  final String ownerPhone;
  final List<CampaignBookingPet> pets;
  final String? paymentStatus;
  final DateTime? checkedInAt;
  final DateTime? completedAt;
  final String? bookingMode;
  final bool pendingAssignment;
  final String? coverageZoneName;
  final String? bookingArea;

  const CampaignBooking({
    required this.id,
    required this.bookingRef,
    this.qrToken,
    required this.status,
    this.bookingDate,
    this.campaignName,
    this.locationName,
    this.locationAddress,
    this.slotStart,
    this.slotEnd,
    required this.ownerName,
    required this.ownerPhone,
    required this.pets,
    this.paymentStatus,
    this.checkedInAt,
    this.completedAt,
    this.bookingMode,
    this.pendingAssignment = false,
    this.coverageZoneName,
    this.bookingArea,
  });

  bool get isUpcoming {
    if (bookingDate == null) return false;
    final today = DateTime.now();
    final d = DateTime(bookingDate!.year, bookingDate!.month, bookingDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return !d.isBefore(t) && status != 'COMPLETED' && status != 'CANCELLED';
  }

  bool get isHistory =>
      status == 'COMPLETED' || status == 'CANCELLED' || status == 'NO_SHOW';

  factory CampaignBooking.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    final slot = json['slot'];
    final campaign = json['campaign'];
    final petsRaw = json['pets'];
    final pets = petsRaw is List
        ? petsRaw
            .whereType<Map>()
            .map((e) => CampaignBookingPet.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <CampaignBookingPet>[];

    return CampaignBooking(
      id: campaignJsonInt(json['id']),
      bookingRef: json['bookingRef']?.toString() ?? '',
      qrToken: json['qrToken']?.toString(),
      status: json['status']?.toString() ?? 'CONFIRMED',
      bookingDate: campaignJsonDate(json['bookingDate']),
      campaignName: campaign is Map ? campaign['name']?.toString() : null,
      locationName: location is Map ? location['name']?.toString() : null,
      locationAddress: location is Map ? location['address']?.toString() : null,
      slotStart: slot is Map ? slot['startTime']?.toString() : null,
      slotEnd: slot is Map ? slot['endTime']?.toString() : null,
      ownerName: json['owner'] is Map
          ? json['owner']['name']?.toString() ?? ''
          : json['ownerName']?.toString() ?? '',
      ownerPhone: json['owner'] is Map
          ? json['owner']['phone']?.toString() ?? ''
          : json['ownerPhone']?.toString() ?? '',
      pets: pets,
      paymentStatus: json['paymentStatus']?.toString(),
      checkedInAt: campaignJsonDate(json['checkedInAt']),
      completedAt: campaignJsonDate(json['completedAt']),
      bookingMode: json['bookingMode']?.toString(),
      pendingAssignment: json['pendingAssignment'] == true,
      coverageZoneName: json['coverageZoneName']?.toString(),
      bookingArea: json['bookingArea']?.toString(),
    );
  }
}

class VaccinationRecord {
  final int id;
  final String source;
  final String petName;
  final int? petId;
  final String? animalType;
  final String? breed;
  final String vaccineType;
  final DateTime? administeredAt;
  final DateTime? nextDueDate;
  final String? certificateToken;
  final String? campaignName;
  final String? location;
  final String? bookingRef;

  const VaccinationRecord({
    required this.id,
    required this.source,
    required this.petName,
    this.petId,
    this.animalType,
    this.breed,
    required this.vaccineType,
    this.administeredAt,
    this.nextDueDate,
    this.certificateToken,
    this.campaignName,
    this.location,
    this.bookingRef,
  });

  factory VaccinationRecord.fromJson(Map<String, dynamic> json) {
    return VaccinationRecord(
      id: campaignJsonInt(json['id']),
      source: json['source']?.toString() ?? 'campaign',
      petName: json['petName']?.toString() ?? 'Pet',
      petId: json['petId'] == null ? null : campaignJsonInt(json['petId']),
      animalType: json['animalType']?.toString(),
      breed: json['breed']?.toString(),
      vaccineType: json['vaccineType']?.toString() ?? 'Vaccination',
      administeredAt: campaignJsonDate(json['administeredAt']),
      nextDueDate: campaignJsonDate(json['nextDueDate']),
      certificateToken: json['certificateToken']?.toString(),
      campaignName: json['campaignName']?.toString(),
      location: json['location']?.toString(),
      bookingRef: json['bookingRef']?.toString(),
    );
  }
}

class UpcomingVaccination {
  final int id;
  final String bookingRef;
  final DateTime? bookingDate;
  final String status;
  final String campaignName;
  final String locationName;
  final String? locationAddress;
  final String? slotStart;
  final String? slotEnd;
  final String? qrToken;
  final List<CampaignBookingPet> pets;

  const UpcomingVaccination({
    required this.id,
    required this.bookingRef,
    this.bookingDate,
    required this.status,
    required this.campaignName,
    required this.locationName,
    this.locationAddress,
    this.slotStart,
    this.slotEnd,
    this.qrToken,
    required this.pets,
  });

  factory UpcomingVaccination.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    final slot = json['slot'];
    final petsRaw = json['pets'];
    final pets = petsRaw is List
        ? petsRaw
            .whereType<Map>()
            .map((e) => CampaignBookingPet.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <CampaignBookingPet>[];

    return UpcomingVaccination(
      id: campaignJsonInt(json['id']),
      bookingRef: json['bookingRef']?.toString() ?? '',
      bookingDate: campaignJsonDate(json['bookingDate']),
      status: json['status']?.toString() ?? 'CONFIRMED',
      campaignName: json['campaignName']?.toString() ?? 'Campaign',
      locationName: location is Map
          ? location['name']?.toString() ?? 'Location'
          : 'Location',
      locationAddress: location is Map ? location['address']?.toString() : null,
      slotStart: slot is Map ? slot['startTime']?.toString() : null,
      slotEnd: slot is Map ? slot['endTime']?.toString() : null,
      qrToken: json['qrToken']?.toString(),
      pets: pets,
    );
  }
}

class CampaignBenefits {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? pricingType;
  final num? priceAmount;
  final List<String> benefits;
  final List<Map<String, dynamic>> vaccineTypes;
  final List<Map<String, dynamic>> locations;

  const CampaignBenefits({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.startDate,
    this.endDate,
    this.pricingType,
    this.priceAmount,
    required this.benefits,
    required this.vaccineTypes,
    required this.locations,
  });

  factory CampaignBenefits.fromJson(Map<String, dynamic> json) {
    return CampaignBenefits(
      id: campaignJsonInt(json['id']),
      name: json['name']?.toString() ?? 'Campaign',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      startDate: campaignJsonDate(json['startDate']),
      endDate: campaignJsonDate(json['endDate']),
      pricingType: json['pricingType']?.toString(),
      priceAmount: json['priceAmount'] is num ? json['priceAmount'] as num : null,
      benefits: json['benefits'] is List
          ? (json['benefits'] as List).map((e) => e.toString()).toList()
          : const [],
      vaccineTypes: json['vaccineTypes'] is List
          ? (json['vaccineTypes'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
      locations: json['locations'] is List
          ? (json['locations'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
    );
  }
}

class CertificateData {
  final String certificateToken;
  final String petName;
  final String ownerName;
  final String ownerPhone;
  final String animalType;
  final String? breed;
  final String vaccineType;
  final DateTime? vaccinatedAt;
  final DateTime? validUntil;
  final String? batchNumber;
  final String location;
  final String campaignName;
  final String qrCodeImage;
  final DateTime? issuedAt;

  const CertificateData({
    required this.certificateToken,
    required this.petName,
    required this.ownerName,
    required this.ownerPhone,
    required this.animalType,
    this.breed,
    required this.vaccineType,
    this.vaccinatedAt,
    this.validUntil,
    this.batchNumber,
    required this.location,
    required this.campaignName,
    required this.qrCodeImage,
    this.issuedAt,
  });

  factory CertificateData.fromJson(Map<String, dynamic> json) {
    return CertificateData(
      certificateToken: json['certificateToken']?.toString() ?? '',
      petName: json['petName']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      ownerPhone: json['ownerPhone']?.toString() ?? '',
      animalType: json['animalType']?.toString() ?? '',
      breed: json['breed']?.toString(),
      vaccineType: json['vaccineType']?.toString() ?? '',
      vaccinatedAt: campaignJsonDate(json['vaccinatedAt']),
      validUntil: campaignJsonDate(json['validUntil']),
      batchNumber: json['batchNumber']?.toString(),
      location: json['location']?.toString() ?? '',
      campaignName: json['campaignName']?.toString() ?? '',
      qrCodeImage: json['qrCodeImage']?.toString() ?? '',
      issuedAt: campaignJsonDate(json['issuedAt']),
    );
  }
}

class CertificatePdfData {
  final String pdfBase64;
  final String filename;

  const CertificatePdfData({required this.pdfBase64, required this.filename});

  factory CertificatePdfData.fromJson(Map<String, dynamic> json) {
    return CertificatePdfData(
      pdfBase64: json['pdf']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'certificate.pdf',
    );
  }
}

class VaccinationReminder {
  final String id;
  final String petName;
  final String vaccineType;
  final DateTime dueDate;
  final bool enabled;
  final int daysBefore;

  const VaccinationReminder({
    required this.id,
    required this.petName,
    required this.vaccineType,
    required this.dueDate,
    required this.enabled,
    this.daysBefore = 7,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'petName': petName,
        'vaccineType': vaccineType,
        'dueDate': dueDate.toIso8601String(),
        'enabled': enabled,
        'daysBefore': daysBefore,
      };

  factory VaccinationReminder.fromJson(Map<String, dynamic> json) {
    return VaccinationReminder(
      id: json['id']?.toString() ?? '',
      petName: json['petName']?.toString() ?? '',
      vaccineType: json['vaccineType']?.toString() ?? '',
      dueDate: campaignJsonDate(json['dueDate']) ?? DateTime.now(),
      enabled: json['enabled'] != false,
      daysBefore: campaignJsonInt(json['daysBefore'], fallback: 7),
    );
  }
}

int campaignJsonInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

DateTime? campaignJsonDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
