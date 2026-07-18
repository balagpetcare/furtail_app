class AdoptionListingFormPayload {
  final String name;
  final String species;
  final String breed;
  final String ageText;
  final int? ageYears;
  final int? ageMonths;
  final int? ageDays;
  final int? totalAgeDays;
  final String? approximateDateOfBirth;
  final String gender;
  final String sizeText;
  final String colorText;
  final String description;
  final String adoptionReason;
  final bool vaccinated;
  final bool dewormed;
  final bool neutered;
  final bool microchipped;
  final String healthInfo;
  final String ownerContactPhone;
  final String ownerWhatsappPhone;
  final String ownerCityAreaText;
  final String pickupLocationNotes;
  final int countryId;
  final int? bdDivisionId;
  final int? bdDistrictId;
  final int? bdUpazilaId;
  final int? bdAreaId;
  final String serviceAreaType;
  final bool allowInternationalAdoption;
  final String customServiceAreasText;
  final String serviceAreaNotes;
  final bool previousPetExperienceRequired;
  final bool familyApprovalRequired;
  final bool canProvideVetCare;
  final bool noResaleAgreement;
  final bool followUpAgreement;
  final String minimumIncomeRange;
  final String maximumIncomeRange;
  final String adopterConditionNote;
  final double? latitude;
  final double? longitude;
  final List<int> mediaIds;

  const AdoptionListingFormPayload({
    required this.name,
    required this.species,
    required this.breed,
    required this.ageText,
    this.ageYears,
    this.ageMonths,
    this.ageDays,
    this.totalAgeDays,
    this.approximateDateOfBirth,
    required this.gender,
    required this.sizeText,
    required this.colorText,
    required this.description,
    required this.adoptionReason,
    required this.vaccinated,
    required this.dewormed,
    required this.neutered,
    required this.microchipped,
    required this.healthInfo,
    required this.ownerContactPhone,
    required this.ownerWhatsappPhone,
    required this.ownerCityAreaText,
    required this.pickupLocationNotes,
    required this.countryId,
    this.bdDivisionId,
    this.bdDistrictId,
    this.bdUpazilaId,
    this.bdAreaId,
    required this.serviceAreaType,
    required this.allowInternationalAdoption,
    required this.customServiceAreasText,
    required this.serviceAreaNotes,
    required this.previousPetExperienceRequired,
    required this.familyApprovalRequired,
    required this.canProvideVetCare,
    required this.noResaleAgreement,
    required this.followUpAgreement,
    required this.minimumIncomeRange,
    required this.maximumIncomeRange,
    required this.adopterConditionNote,
    this.latitude,
    this.longitude,
    this.mediaIds = const [],
  });

  Map<String, dynamic> toApiPayload({required bool submitNow}) {
    final adopterConditions = <String>[
      if (previousPetExperienceRequired) 'Previous pet experience required',
      if (familyApprovalRequired) 'Family approval required',
      if (canProvideVetCare) 'Must be able to provide vet care',
      if (noResaleAgreement) 'No resale or abandonment agreement required',
      if (followUpAgreement) 'Post-adoption follow-up agreement required',
      if (_trim(adopterConditionNote).isNotEmpty) _trim(adopterConditionNote),
    ];

    return {
      'submitNow': submitNow,
      'ownerType': 'INDIVIDUAL',
      'countryId': countryId,
      if (bdDivisionId != null) 'bdDivisionId': bdDivisionId,
      if (bdDistrictId != null) 'bdDistrictId': bdDistrictId,
      if (bdUpazilaId != null) 'bdUpazilaId': bdUpazilaId,
      if (bdAreaId != null) 'bdAreaId': bdAreaId,
      'species': species,
      'name': _trim(name),
      if (_trim(breed).isNotEmpty) 'breed': _trim(breed),
      if (_trim(ageText).isNotEmpty) 'ageText': _trim(ageText),
      if (ageYears != null) 'ageYears': ageYears,
      if (ageMonths != null) 'ageMonths': ageMonths,
      if (ageDays != null) 'ageDays': ageDays,
      if (totalAgeDays != null) 'totalAgeDays': totalAgeDays,
      if (approximateDateOfBirth != null) 'approximateDateOfBirth': approximateDateOfBirth,
      if (_trim(gender).isNotEmpty) 'gender': gender,
      if (_trim(sizeText).isNotEmpty) 'sizeText': _trim(sizeText),
      if (_trim(colorText).isNotEmpty) 'colorText': _trim(colorText),
      'title': 'Adopt ${_trim(name)}',
      'description': _trim(description),
      'story': 'Reason for adoption: ${_trim(adoptionReason)}',
      if (_trim(healthInfo).isNotEmpty) 'healthInfo': _trim(healthInfo),
      'ownerContactPhone': _trim(ownerContactPhone),
      if (_trim(ownerWhatsappPhone).isNotEmpty)
        'ownerWhatsappPhone': _trim(ownerWhatsappPhone),
      'ownerCityAreaText': _trim(ownerCityAreaText),
      'pickupLocationNotes': _trim(pickupLocationNotes),
      'serviceAreaType': serviceAreaType,
      if (_trim(serviceAreaNotes).isNotEmpty)
        'serviceAreaNotes': _trim(serviceAreaNotes),
      if (_customAreas.isNotEmpty) 'customServiceAreasJson': _customAreas,
      'allowInternationalAdoption': allowInternationalAdoption,
      'vaccinated': vaccinated,
      'dewormed': dewormed,
      'neutered': neutered,
      'microchipped': microchipped,
      if (adopterConditions.isNotEmpty)
        'adopterConditionsJson': adopterConditions,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
      'criteria': {
        'adoptionExperienceRequired': previousPetExperienceRequired,
        'homeCheckRequired': followUpAgreement,
        'vetReferenceRequired': canProvideVetCare,
        'identityVerificationRequired': noResaleAgreement,
        'landlordApprovalRequired': familyApprovalRequired,
        if (_trim(minimumIncomeRange).isNotEmpty)
          'minimumMonthlyIncomeRange': _trim(minimumIncomeRange),
        if (_trim(maximumIncomeRange).isNotEmpty)
          'maximumMonthlyIncomeRange': _trim(maximumIncomeRange),
        if (_trim(adopterConditionNote).isNotEmpty)
          'notes': _trim(adopterConditionNote),
      },
    };
  }

  List<String> get _customAreas => customServiceAreasText
      .split(',')
      .map(_trim)
      .where((item) => item.isNotEmpty)
      .toList();

  static String _trim(String value) => value.trim();
}
