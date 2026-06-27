class AdoptionPetUiModel {
  final int id;
  final String name;
  final String species;
  final String breed;
  final String ageLabel;
  final String gender;
  final String location;
  final String description;
  final bool vaccinated;
  final bool dewormed;
  final bool neutered;
  final bool microchipped;
  final bool isShelter;
  final String ownerName;
  final int? ownerUserId;
  final String ownerRoleLabel;
  final String status;
  final List<String> galleryLabels;
  final List<String> personalityTags;
  final List<String> compatibilityTags;
  final List<String> serviceAreas;
  final List<String> adopterConditions;
  final String story;
  final String healthNotes;
  final String? coverImageUrl;
  final List<String> galleryImageUrls;

  const AdoptionPetUiModel({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.ageLabel,
    required this.gender,
    required this.location,
    required this.description,
    required this.vaccinated,
    required this.dewormed,
    required this.neutered,
    required this.microchipped,
    required this.isShelter,
    required this.ownerName,
    this.ownerUserId,
    required this.ownerRoleLabel,
    required this.status,
    required this.galleryLabels,
    required this.personalityTags,
    required this.compatibilityTags,
    required this.serviceAreas,
    required this.adopterConditions,
    required this.story,
    required this.healthNotes,
    this.coverImageUrl,
    this.galleryImageUrls = const [],
  });

  bool get hasHealthBadge => vaccinated || dewormed;

  AdoptionPetUiModel copyWith({
    int? id,
    String? name,
    String? species,
    String? breed,
    String? ageLabel,
    String? gender,
    String? location,
    String? description,
    bool? vaccinated,
    bool? dewormed,
    bool? neutered,
    bool? microchipped,
    bool? isShelter,
    String? ownerName,
    int? ownerUserId,
    String? ownerRoleLabel,
    String? status,
    List<String>? galleryLabels,
    List<String>? personalityTags,
    List<String>? compatibilityTags,
    List<String>? serviceAreas,
    List<String>? adopterConditions,
    String? story,
    String? healthNotes,
    String? coverImageUrl,
    List<String>? galleryImageUrls,
  }) {
    return AdoptionPetUiModel(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      ageLabel: ageLabel ?? this.ageLabel,
      gender: gender ?? this.gender,
      location: location ?? this.location,
      description: description ?? this.description,
      vaccinated: vaccinated ?? this.vaccinated,
      dewormed: dewormed ?? this.dewormed,
      neutered: neutered ?? this.neutered,
      microchipped: microchipped ?? this.microchipped,
      isShelter: isShelter ?? this.isShelter,
      ownerName: ownerName ?? this.ownerName,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerRoleLabel: ownerRoleLabel ?? this.ownerRoleLabel,
      status: status ?? this.status,
      galleryLabels: galleryLabels ?? this.galleryLabels,
      personalityTags: personalityTags ?? this.personalityTags,
      compatibilityTags: compatibilityTags ?? this.compatibilityTags,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      adopterConditions: adopterConditions ?? this.adopterConditions,
      story: story ?? this.story,
      healthNotes: healthNotes ?? this.healthNotes,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
    );
  }

  static AdoptionPetUiModel fromApiJson(Map<String, dynamic> json) {
    final mediaList = _asMapList(json['media']);
    final galleryImageUrls = mediaList
        .map((item) {
          final media = item['media'];
          if (media is Map) {
            final url = _asString(media['url']);
            if (url.isNotEmpty) return url;
            final thumb = _asString(media['thumbnailUrl']);
            if (thumb.isNotEmpty) return thumb;
          }
          return '';
        })
        .where((item) => item.isNotEmpty)
        .toList();

    final galleryLabels = galleryImageUrls.isNotEmpty
        ? List<String>.generate(
            galleryImageUrls.length,
            (index) => 'Photo ${index + 1}',
          )
        : const ['Media placeholder'];

    final owner = _asMap(json['owner']);
    final ownerProfile = _asMap(owner['profile']);
    final shelter = _asMap(json['shelterProfile']);
    final country = _asMap(json['country']);
    final criteria = _asMap(json['criteria']);

    final ownerName = _firstNonEmpty([
      _asString(shelter['displayName']),
      _asString(ownerProfile['displayName']),
      _asString(ownerProfile['username']),
      'Furtail user',
    ]);

    final ownerRoleLabel = _ownerRoleLabel(
      ownerType: _asString(json['ownerType']),
      shelterName: _asString(shelter['displayName']),
    );

    final serviceAreas = {
      ..._asStringList(json['customServiceAreasJson']),
      if (_asString(json['serviceAreaNotes']).isNotEmpty)
        _asString(json['serviceAreaNotes']),
      if (_asString(country['name']).isNotEmpty) _asString(country['name']),
    }.toList();

    final ageText = _asString(json['ageText']);
    final breed = _asString(json['breed']);
    final species = _speciesLabel(_asString(json['species']));
    final gender = _genderLabel(_asString(json['gender']));
    final status = _statusLabel(
      _asString(json['applicationStatus']).isNotEmpty
          ? _asString(json['applicationStatus'])
          : _asString(json['status']),
    );

    return AdoptionPetUiModel(
      id: _asInt(json['id']),
      name: _firstNonEmpty([_asString(json['name']), 'Unnamed pet']),
      species: species,
      breed: breed.isNotEmpty ? breed : 'Breed not specified',
      ageLabel: ageText.isNotEmpty ? ageText : 'Age not specified',
      gender: gender,
      location: _firstNonEmpty([
        _asString(country['name']),
        'Bangladesh',
      ]),
      description: _firstNonEmpty([
        _asString(json['description']),
        _asString(json['story']),
        'Adoption details will appear here when available.',
      ]),
      vaccinated: _asBool(json['vaccinated']),
      dewormed: _asBool(json['dewormed']),
      neutered: _asBool(json['neutered']),
      microchipped: _asBool(json['microchipped']),
      isShelter: _asString(shelter['displayName']).isNotEmpty ||
          _asString(json['ownerType']) == 'SHELTER' ||
          _asString(json['ownerType']) == 'RESCUE',
      ownerName: ownerName,
      ownerUserId: _asIntOrNull(owner['id']),
      ownerRoleLabel: ownerRoleLabel,
      status: status,
      galleryLabels: galleryLabels,
      personalityTags: _asStringList(json['personalityTagsJson']),
      compatibilityTags: _asStringList(json['compatibilityTagsJson']),
      serviceAreas: serviceAreas.isNotEmpty ? serviceAreas : const ['Bangladesh'],
      adopterConditions: {
        ..._asStringList(json['adopterConditionsJson']),
        ..._criteriaConditions(criteria),
      }.toList(),
      story: _firstNonEmpty([
        _asString(json['story']),
        _asString(json['description']),
        'No adoption story shared yet.',
      ]),
      healthNotes: _firstNonEmpty([
        _asString(json['healthInfo']),
        'No health notes available yet.',
      ]),
      coverImageUrl: galleryImageUrls.isNotEmpty ? galleryImageUrls.first : null,
      galleryImageUrls: galleryImageUrls,
    );
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => _asString(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _asString(dynamic value) => value?.toString().trim() ?? '';
  static int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
  static int? _asIntOrNull(dynamic value) => int.tryParse(value?.toString() ?? '');
  static bool _asBool(dynamic value) => value == true;

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String _speciesLabel(String value) {
    switch (value.toUpperCase()) {
      case 'CAT':
        return 'Cats';
      case 'DOG':
        return 'Dogs';
      case 'BIRD':
        return 'Birds';
      case 'RABBIT':
        return 'Rabbits';
      case 'OTHER':
        return 'Other';
      default:
        return value.isNotEmpty ? value : 'Other';
    }
  }

  static String _genderLabel(String value) {
    switch (value.toUpperCase()) {
      case 'MALE':
        return 'Male';
      case 'FEMALE':
        return 'Female';
      default:
        return 'Unknown';
    }
  }

  static String _statusLabel(String value) {
    switch (value.toUpperCase()) {
      case 'DRAFT':
        return 'Draft';
      case 'PENDING_REVIEW':
        return 'Pending Review';
      case 'APPROVED':
        return 'Approved';
      case 'PUBLISHED':
        return 'Published';
      case 'AVAILABLE':
        return 'Available';
      case 'PENDING':
      case 'SUBMITTED':
      case 'OWNER_REVIEW':
      case 'SHORTLISTED':
      case 'MESSAGE_STARTED':
      case 'INTERVIEW_SCHEDULED':
      case 'HOME_CHECK_REQUESTED':
        return 'Pending';
      case 'ADOPTED':
      case 'ADOPTION_COMPLETED':
        return 'Adopted';
      case 'PAUSED':
        return 'Paused';
      case 'APPLICATION_CLOSED':
        return 'Applications Closed';
      case 'NEEDS_CHANGES':
        return 'Needs changes';
      case 'REJECTED':
        return 'Rejected';
      case 'REPORTED':
        return 'Reported';
      case 'REMOVED':
        return 'Removed';
      case 'EXPIRED':
        return 'Expired';
      default:
        if (value.isEmpty) return 'Available';
        return value
            .toLowerCase()
            .split('_')
            .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  static String _ownerRoleLabel({
    required String ownerType,
    required String shelterName,
  }) {
    switch (ownerType.toUpperCase()) {
      case 'SHELTER':
        return 'Shelter';
      case 'RESCUE':
        return 'Rescue';
      case 'FOSTER':
        return 'Foster';
      case 'ADMIN':
        return 'Admin';
      case 'INDIVIDUAL':
        return 'Owner';
      default:
        return shelterName.isNotEmpty ? 'Shelter' : 'Owner';
    }
  }

  static List<String> _criteriaConditions(Map<String, dynamic> criteria) {
    final out = <String>[];
    if (_asBool(criteria['homeCheckRequired'])) out.add('Home check required');
    if (_asBool(criteria['identityVerificationRequired'])) {
      out.add('Identity verification required');
    }
    if (_asBool(criteria['vetReferenceRequired'])) {
      out.add('Vet reference preferred');
    }
    if (_asBool(criteria['landlordApprovalRequired'])) {
      out.add('Landlord approval required');
    }
    final minAge = criteria['minimumAdopterAgeYears'];
    if (minAge != null) out.add('Minimum adopter age: $minAge');
    return out;
  }
}
