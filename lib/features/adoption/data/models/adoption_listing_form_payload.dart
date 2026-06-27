class AdoptionListingFormPayload {
  final String name;
  final String species;
  final String breed;
  final String ageText;
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
  final String countryIdText;
  final String stateIdText;
  final String cityIdText;
  final String divisionIdText;
  final String districtIdText;
  final String upazilaIdText;
  final String areaIdText;
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

  const AdoptionListingFormPayload({
    required this.name,
    required this.species,
    required this.breed,
    required this.ageText,
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
    required this.countryIdText,
    required this.stateIdText,
    required this.cityIdText,
    required this.divisionIdText,
    required this.districtIdText,
    required this.upazilaIdText,
    required this.areaIdText,
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
      'countryId': _parseRequiredInt(countryIdText),
      'stateId': _parseOptionalInt(stateIdText),
      'cityId': _parseOptionalInt(cityIdText),
      'bdDivisionId': _parseOptionalInt(divisionIdText),
      'bdDistrictId': _parseOptionalInt(districtIdText),
      'bdUpazilaId': _parseOptionalInt(upazilaIdText),
      'bdAreaId': _parseOptionalInt(areaIdText),
      'species': species,
      'name': _trim(name),
      if (_trim(breed).isNotEmpty) 'breed': _trim(breed),
      if (_trim(ageText).isNotEmpty) 'ageText': _trim(ageText),
      if (_trim(gender).isNotEmpty) 'gender': gender,
      if (_trim(sizeText).isNotEmpty) 'sizeText': _trim(sizeText),
      if (_trim(colorText).isNotEmpty) 'colorText': _trim(colorText),
      'title': 'Adopt ${_trim(name)}',
      'description': _trim(description),
      'story': 'Reason for adoption: ${_trim(adoptionReason)}',
      if (_trim(healthInfo).isNotEmpty) 'healthInfo': _trim(healthInfo),
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

  static int _parseRequiredInt(String value) {
    final parsed = _parseOptionalInt(value);
    if (parsed == null) {
      throw const FormatException('Country ID is required.');
    }
    return parsed;
  }

  static int? _parseOptionalInt(String value) {
    final trimmed = _trim(value);
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  static String _trim(String value) => value.trim();
}
