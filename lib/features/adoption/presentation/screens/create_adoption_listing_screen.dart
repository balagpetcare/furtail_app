import 'dart:io';

import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/media/image_editor_screen.dart';
import 'package:furtail_app/core/media/video_edit_screen.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/dtos/pets/animal_type_dto.dart';
import 'package:furtail_app/dtos/pets/breed_dto.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_media_models.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_listing_form_payload.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_listing_preview_screen.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/common/data/repositories/bd_locations_repository.dart';
import 'package:furtail_app/features/legacy/data/models/country_model.dart';
import 'package:furtail_app/features/profile/data/profile_service.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _speciesLabels = <String, String>{
  'CAT': 'Cat',
  'DOG': 'Dog',
  'BIRD': 'Bird',
  'RABBIT': 'Rabbit',
  'OTHER': 'Other',
};

const _genderLabels = <String, String>{
  'UNKNOWN': 'Not specified',
  'MALE': 'Male',
  'FEMALE': 'Female',
};

const _serviceAreaLabels = <String, String>{
  'SAME_AREA': 'Same area',
  'SAME_CITY': 'Same city',
  'SAME_DISTRICT': 'Same district',
  'SAME_DIVISION': 'Same division',
  'ANYWHERE_COUNTRY': 'Anywhere in country',
  'CUSTOM_AREAS': 'Custom areas',
  'RADIUS_BASED': 'Radius based',
  'INTERNATIONAL': 'International',
};

String _normalizeSpeciesKey(String value) {
  switch (value.trim().toUpperCase()) {
    case 'CAT':
    case 'CATS':
      return 'CAT';
    case 'DOG':
    case 'DOGS':
      return 'DOG';
    case 'BIRD':
    case 'BIRDS':
      return 'BIRD';
    case 'RABBIT':
    case 'RABBITS':
      return 'RABBIT';
    case 'OTHER':
      return 'OTHER';
    default:
      return value.trim().toUpperCase();
  }
}

String _normalizeEnumKey(String value) => value.trim().toUpperCase();

String? _safeStringSelection(
  String? current,
  Iterable<String> options, {
  required String Function(String value) normalize,
}) {
  if (current == null) return null;
  final key = normalize(current);
  final matches = options.where((option) => normalize(option) == key).toList();
  return matches.length == 1 ? key : null;
}

List<String> _uniqueStrings(
  Iterable<String> values, {
  required String Function(String value) normalize,
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final value in values) {
    final key = normalize(value);
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(key);
  }
  return out;
}

T? _safeObjectSelection<T>(
  T? current,
  Iterable<T> items,
  int Function(T item) keyOf,
) {
  if (current == null) return null;
  final key = keyOf(current);
  final matches = items.where((item) => keyOf(item) == key).toList();
  return matches.length == 1 ? matches.single : null;
}

List<T> _uniqueObjects<T>(Iterable<T> items, int Function(T item) keyOf) {
  final seen = <int>{};
  final out = <T>[];
  for (final item in items) {
    final key = keyOf(item);
    if (!seen.add(key)) continue;
    out.add(item);
  }
  return out;
}

enum _AdoptionStep { basicInfo, story, health, location, conditions, preview }

extension _AdoptionStepExt on _AdoptionStep {
  String get label => switch (this) {
    _AdoptionStep.basicInfo => 'Basic Info',
    _AdoptionStep.story => 'Story',
    _AdoptionStep.health => 'Health',
    _AdoptionStep.location => 'Location',
    _AdoptionStep.conditions => 'Conditions',
    _AdoptionStep.preview => 'Preview',
  };
}

class CreateAdoptionListingScreen extends StatefulWidget {
  final AdoptionPetUiModel? existingListing;
  const CreateAdoptionListingScreen({super.key, this.existingListing});

  @override
  State<CreateAdoptionListingScreen> createState() =>
      _CreateAdoptionListingScreenState();
}

class _CreateAdoptionListingScreenState
    extends State<CreateAdoptionListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  late final AdoptionRepository _repository;
  late final BdLocationsRepository _locationRepo;
  final _postsDs = PostsRemoteDs();
  final _picker = ImagePicker();
  final _profileService = ProfileService();
  final _localNotifications = FlutterLocalNotificationsPlugin();
  static const int _uploadNotificationId = 9999;

  // controllers
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _healthCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _ownerWhatsappCtrl = TextEditingController();
  final _ownerCityAreaCtrl = TextEditingController();
  final _pickupNotesCtrl = TextEditingController();
  final _customAreasCtrl = TextEditingController();
  final _areaNotesCtrl = TextEditingController();
  final _minIncomeCtrl = TextEditingController();
  final _maxIncomeCtrl = TextEditingController();
  final _conditionNoteCtrl = TextEditingController();
  final _breedFallbackCtrl = TextEditingController();
  final _colorFallbackCtrl = TextEditingController();

  int? _ageYears = 0;
  int? _ageMonths = 0;
  int? _ageDays = 0;
  String? _selectedSize;
  List<String> _selectedColors = [];
  String? _selectedBreedName;

  bool get _isAgeValid =>
      (_ageYears ?? 0) + (_ageMonths ?? 0) + (_ageDays ?? 0) > 0;

  bool get _isBasicInfoComplete {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_species.isEmpty) return false;
    if (!_isAgeValid) return false;
    if (_selectedBreedName == null || _selectedBreedName!.isEmpty) return false;
    if (_selectedBreedName == 'Other' && _breedFallbackCtrl.text.trim().isEmpty)
      return false;
    if (_gender == 'UNKNOWN' || _gender.isEmpty) return false;
    if (_selectedSize == null ||
        _selectedSize == 'Unknown' ||
        _selectedSize!.isEmpty)
      return false;
    if (_selectedColors.isEmpty) return false;
    if (_selectedColors.contains('Other') &&
        _colorFallbackCtrl.text.trim().isEmpty)
      return false;
    return true;
  }

  String getFormattedAge() {
    final parts = <String>[];
    if (_ageYears != null && _ageYears! > 0) {
      parts.add(_ageYears == 1 ? '1 year' : '$_ageYears years');
    }
    if (_ageMonths != null && _ageMonths! > 0) {
      parts.add(_ageMonths == 1 ? '1 month' : '$_ageMonths months');
    }
    if (_ageDays != null && _ageDays! > 0) {
      parts.add(_ageDays == 1 ? '1 day' : '$_ageDays days');
    }
    return parts.join(' ');
  }

  String getBreedValue() {
    if (_selectedBreedName == 'Other') {
      final note = _breedFallbackCtrl.text.trim();
      return note.isNotEmpty ? 'Other ($note)' : 'Other';
    }
    return _selectedBreedName ?? 'Unknown';
  }

  String getColorValue() {
    final list = List<String>.from(_selectedColors);
    if (list.contains('Other')) {
      final note = _colorFallbackCtrl.text.trim();
      if (note.isNotEmpty) {
        list.remove('Other');
        list.add('Other ($note)');
      }
    }
    return list.join(', ');
  }

  List<String> getBreedOptions() {
    final list = <String>[];
    list.addAll(_breeds.map((b) => b.name));
    final std = ['Local/Indigenous', 'Mixed breed', 'Unknown', 'Other'];
    for (final opt in std) {
      if (!list.contains(opt)) {
        list.add(opt);
      }
    }
    return list;
  }

  // species / breed
  String _species = 'CAT';
  List<AnimalTypeDto> _animalTypes = const [];
  int? _selectedTypeId;
  List<BreedDto> _breeds = const [];
  bool _loadingBreeds = false;

  // gender / service area
  String _gender = 'UNKNOWN';
  String _serviceAreaType = 'ANYWHERE_COUNTRY';

  // health toggles
  bool _vaccinated = false;
  bool _dewormed = false;
  bool _neutered = false;
  bool _microchipped = false;
  bool _allowIntl = false;

  // adopter conditions
  bool _prevPetExp = false;
  bool _familyApproval = false;
  bool _vetCare = false;
  bool _noResale = true;
  bool _followUp = false;

  // location
  Country? _bangladeshCountry;
  String? _countryError;
  List<BdDivision> _divisions = const [];
  List<BdDistrict> _districts = const [];
  List<BdUpazila> _upazilas = const [];
  List<BdArea> _areas = const [];
  BdDivision? _selDivision;
  BdDistrict? _selDistrict;
  BdUpazila? _selUpazila;
  BdArea? _selArea;
  bool _loadingDistricts = false;
  bool _loadingUpazilas = false;
  bool _loadingAreas = false;

  // GPS
  double? _latitude;
  double? _longitude;
  bool _gpsLoading = false;
  String? _gpsText;

  // media
  final List<AdoptionDraftMediaItem> _mediaItems = [];
  bool _mediaUploading = false;
  final Set<int> _editingIndexes = {};
  bool _pickingMedia = false;

  // UI
  int _stepIndex = 0;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;
  bool _isSavingDraft = false;

  // section-level validation flags
  final Map<int, String?> _sectionErrors = {};

  // Public wrapper — page sub-widgets call this instead of setState directly
  void update(VoidCallback fn) => setState(fn);

  bool get _hasFailedUploads => _mediaItems.any((item) => item.uploadFailed);
  bool get _hasActiveUploads => _mediaItems.any((item) => item.isUploading);
  bool get _hasIncompleteRequiredFields => !_validateAllSilently();
  // Pending items (local/ready-to-upload) do NOT block publish — _publishListing uploads them first.
  bool get _canPublishNow =>
      !_isSavingDraft &&
      !_mediaUploading &&
      !_hasActiveUploads &&
      !_hasFailedUploads &&
      !_hasIncompleteRequiredFields;

  String? get _publishBlockReason {
    if (_isSavingDraft || _mediaUploading) {
      return 'Uploading media before publishing…';
    }
    if (_hasActiveUploads) {
      return 'Uploading media before publishing…';
    }
    if (_hasFailedUploads) {
      return 'Retry or remove failed media before publishing.';
    }
    if (_hasIncompleteRequiredFields) {
      return 'Complete the required listing fields before publishing.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _repository = AdoptionRepository(AdoptionRemoteDs(client));
    _locationRepo = BdLocationsRepository(client);
    _prefillNonLocationFields();
    _checkAuth();
    _resolveBangladeshCountry();
    _loadAnimalTypes();
    _loadDivisions();
  }

  void _prefillNonLocationFields() {
    final pet = widget.existingListing;
    if (pet == null) return;

    _nameCtrl.text = pet.name;
    _species = _normalizeSpeciesKey(pet.species);

    // Prefill structured age
    _ageYears = pet.ageYears ?? 0;
    _ageMonths = pet.ageMonths ?? 0;
    _ageDays = pet.ageDays ?? 0;
    if (_ageYears == 0 &&
        _ageMonths == 0 &&
        _ageDays == 0 &&
        pet.ageLabel != 'Age not specified') {
      final text = pet.ageLabel.toLowerCase();
      final yMatch = RegExp(r'(\d+)\s*year').firstMatch(text);
      if (yMatch != null) _ageYears = int.tryParse(yMatch.group(1) ?? '0') ?? 0;
      final mMatch = RegExp(r'(\d+)\s*month').firstMatch(text);
      if (mMatch != null)
        _ageMonths = int.tryParse(mMatch.group(1) ?? '0') ?? 0;
      final dMatch = RegExp(r'(\d+)\s*day').firstMatch(text);
      if (dMatch != null) _ageDays = int.tryParse(dMatch.group(1) ?? '0') ?? 0;
    }

    // Prefill size
    final allowedSizes = [
      'Toy',
      'Small',
      'Medium',
      'Large',
      'Extra Large',
      'Unknown',
    ];
    final sizeVal = pet.sizeText ?? '';
    _selectedSize = allowedSizes.firstWhere(
      (s) => s.toLowerCase() == sizeVal.toLowerCase(),
      orElse: () => 'Unknown',
    );

    // Prefill color
    final colorVal = pet.colorText ?? '';
    if (colorVal.isNotEmpty) {
      final parts = colorVal.split(',').map((c) => c.trim()).toList();
      _selectedColors = [];
      for (final p in parts) {
        if (p.toLowerCase().startsWith('other')) {
          _selectedColors.add('Other');
          final regex = RegExp(r'Other \((.*)\)');
          final match = regex.firstMatch(p);
          if (match != null) {
            _colorFallbackCtrl.text = match.group(1) ?? '';
          }
        } else {
          final allowedColors = [
            'Black',
            'White',
            'Brown',
            'Golden',
            'Grey',
            'Orange/Ginger',
            'Cream',
            'Mixed',
            'Spotted',
            'Striped',
            'Other',
          ];
          final matchedColor = allowedColors.firstWhere(
            (c) => c.toLowerCase() == p.toLowerCase(),
            orElse: () => '',
          );
          if (matchedColor.isNotEmpty) {
            _selectedColors.add(matchedColor);
          } else {
            if (!_selectedColors.contains('Other')) {
              _selectedColors.add('Other');
            }
            _colorFallbackCtrl.text = p;
          }
        }
      }
    }

    _descCtrl.text = pet.description;

    const prefix = 'Reason for adoption: ';
    if (pet.story.startsWith(prefix)) {
      _reasonCtrl.text = pet.story.substring(prefix.length);
    } else {
      _reasonCtrl.text = pet.story;
    }

    // Prefill gender: match display label back to enum key
    final genderDisplay = pet.gender.trim().toUpperCase();
    if (genderDisplay == 'MALE') {
      _gender = 'MALE';
    } else if (genderDisplay == 'FEMALE') {
      _gender = 'FEMALE';
    } else {
      _gender = 'UNKNOWN';
    }

    _vaccinated = pet.vaccinated;
    _dewormed = pet.dewormed;
    _neutered = pet.neutered;
    _microchipped = pet.microchipped;
    _healthCtrl.text = pet.healthNotes == 'No health notes available yet.'
        ? ''
        : pet.healthNotes;

    _ownerPhoneCtrl.text = pet.ownerContactPhone ?? '';
    _ownerWhatsappCtrl.text = pet.ownerWhatsappPhone ?? '';
    _ownerCityAreaCtrl.text = pet.ownerCityAreaText ?? '';
    _pickupNotesCtrl.text = pet.pickupLocationNotes ?? '';

    _prevPetExp = pet.adopterConditions.contains(
      'Previous pet experience required',
    );
    _familyApproval = pet.adopterConditions.contains(
      'Family approval required',
    );
    _vetCare = pet.adopterConditions.contains(
      'Must be able to provide vet care',
    );
    _noResale = pet.adopterConditions.contains(
      'No resale or abandonment agreement required',
    );
    _followUp = pet.adopterConditions.contains(
      'Post-adoption follow-up agreement required',
    );

    final standardKeys = [
      'Previous pet experience required',
      'Family approval required',
      'Must be able to provide vet care',
      'No resale or abandonment agreement required',
      'Post-adoption follow-up agreement required',
    ];
    final customNotes = pet.adopterConditions
        .where((c) => !standardKeys.contains(c))
        .toList();
    if (customNotes.isNotEmpty) {
      _conditionNoteCtrl.text = customNotes.join(', ');
    }

    if (pet.serviceAreaType != null) {
      _serviceAreaType = pet.serviceAreaType!;
    }

    _latitude = pet.latitude;
    _longitude = pet.longitude;
    if (_latitude != null && _longitude != null) {
      _gpsText =
          '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}';
    }

    for (final m in pet.media) {
      _mediaItems.add(
        AdoptionDraftMediaItem(
          id: m.id?.toString() ?? UniqueKey().toString(),
          file: File(''),
          type: m.type,
          mediaId: m.id,
          url: m.displayUrl,
          uploadState: AdoptionDraftMediaUploadState.uploaded,
          progress: 1,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _sizeCtrl.dispose();
    _colorCtrl.dispose();
    _descCtrl.dispose();
    _reasonCtrl.dispose();
    _healthCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _ownerWhatsappCtrl.dispose();
    _ownerCityAreaCtrl.dispose();
    _pickupNotesCtrl.dispose();
    _customAreasCtrl.dispose();
    _areaNotesCtrl.dispose();
    _minIncomeCtrl.dispose();
    _maxIncomeCtrl.dispose();
    _conditionNoteCtrl.dispose();
    _breedFallbackCtrl.dispose();
    _colorFallbackCtrl.dispose();
    super.dispose();
  }

  // ─── data loaders ────────────────────────────────────────────────────────

  Future<void> _loadAnimalTypes() async {
    try {
      final types = await _repository.fetchAnimalTypes();
      if (!mounted) return;
      setState(() {
        _animalTypes = types;
        _syncTypeToSpecies(_species);
      });
    } catch (_) {}
  }

  void _syncTypeToSpecies(String species) {
    final label = _speciesLabels[species] ?? species;
    final match = _animalTypes.cast<AnimalTypeDto?>().firstWhere(
      (t) => t!.name.toLowerCase() == label.toLowerCase(),
      orElse: () => null,
    );
    if (match != null && match.id != _selectedTypeId) {
      _selectedTypeId = match.id;
      _loadBreeds(match.id);
    }
  }

  Future<void> _loadBreeds(int typeId) async {
    setState(() {
      _loadingBreeds = true;
      _breeds = const [];
      _selectedBreedName = null;
    });
    try {
      final breeds = await _repository.fetchBreedsByType(typeId);
      if (!mounted) return;
      setState(() {
        _breeds = breeds;
        if (widget.existingListing?.breed != null) {
          final breedVal = widget.existingListing!.breed;
          if (breedVal.toLowerCase().startsWith('other')) {
            _selectedBreedName = 'Other';
            final regex = RegExp(r'Other \((.*)\)');
            final match = regex.firstMatch(breedVal);
            if (match != null) {
              _breedFallbackCtrl.text = match.group(1) ?? '';
            }
          } else {
            final defaultOptions = [
              'Local/Indigenous',
              'Mixed breed',
              'Unknown',
            ];
            final matchDefault = defaultOptions.cast<String?>().firstWhere(
              (opt) => opt!.toLowerCase() == breedVal.toLowerCase(),
              orElse: () => null,
            );
            if (matchDefault != null) {
              _selectedBreedName = matchDefault;
            } else {
              final match = _breeds.cast<BreedDto?>().firstWhere(
                (b) => b!.name.toLowerCase() == breedVal.toLowerCase(),
                orElse: () => null,
              );
              if (match != null) {
                _selectedBreedName = match.name;
              } else {
                _selectedBreedName = 'Other';
                _breedFallbackCtrl.text = breedVal;
              }
            }
          }
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingBreeds = false);
    }
  }

  Future<void> _loadDivisions() async {
    try {
      final list = await _locationRepo.getDivisions();
      if (!mounted) return;
      setState(() {
        _divisions = list;
        if (widget.existingListing?.bdDivisionId != null) {
          _selDivision = _divisions.cast<BdDivision?>().firstWhere(
            (d) => d!.id == widget.existingListing!.bdDivisionId,
            orElse: () => null,
          );
          if (_selDivision != null) {
            _onDivisionChanged(_selDivision, prefilling: true);
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _onDivisionChanged(
    BdDivision? d, {
    bool prefilling = false,
  }) async {
    setState(() {
      _selDivision = d;
      if (!prefilling) {
        _selDistrict = null;
        _selUpazila = null;
        _selArea = null;
        _districts = const [];
        _upazilas = const [];
        _areas = const [];
      }
      _loadingDistricts = d != null;
    });
    if (d == null) return;
    try {
      final list = await _locationRepo.getDistricts(divisionId: d.id);
      if (!mounted) return;
      setState(() {
        _districts = list;
        _loadingDistricts = false;
        if (prefilling && widget.existingListing?.bdDistrictId != null) {
          _selDistrict = _districts.cast<BdDistrict?>().firstWhere(
            (dis) => dis!.id == widget.existingListing!.bdDistrictId,
            orElse: () => null,
          );
          if (_selDistrict != null) {
            _onDistrictChanged(_selDistrict, prefilling: true);
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _onDistrictChanged(
    BdDistrict? d, {
    bool prefilling = false,
  }) async {
    setState(() {
      _selDistrict = d;
      if (!prefilling) {
        _selUpazila = null;
        _selArea = null;
        _upazilas = const [];
        _areas = const [];
      }
      _loadingUpazilas = d != null;
    });
    if (d == null) return;
    try {
      final list = await _locationRepo.getUpazilas(districtId: d.id);
      if (!mounted) return;
      setState(() {
        _upazilas = list;
        _loadingUpazilas = false;
        if (prefilling && widget.existingListing?.bdUpazilaId != null) {
          _selUpazila = _upazilas.cast<BdUpazila?>().firstWhere(
            (u) => u!.id == widget.existingListing!.bdUpazilaId,
            orElse: () => null,
          );
          if (_selUpazila != null) {
            _onUpazilaChanged(_selUpazila, prefilling: true);
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUpazilas = false);
    }
  }

  Future<void> _onUpazilaChanged(
    BdUpazila? u, {
    bool prefilling = false,
  }) async {
    setState(() {
      _selUpazila = u;
      if (!prefilling) {
        _selArea = null;
        _areas = const [];
      }
      _loadingAreas = u != null;
    });
    if (u == null) return;
    try {
      final list = await _locationRepo.getAreas(upazilaId: u.id);
      if (!mounted) return;
      setState(() {
        _areas = list;
        _loadingAreas = false;
        if (prefilling && widget.existingListing?.bdAreaId != null) {
          _selArea = _areas.cast<BdArea?>().firstWhere(
            (a) => a!.id == widget.existingListing!.bdAreaId,
            orElse: () => null,
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAreas = false);
    }
  }

  // ─── auth ────────────────────────────────────────────────────────────────

  Future<void> _checkAuth() async {
    final hasSession = await SecureStorageService().hasSession;
    if (hasSession) {
      try {
        final profile = await _profileService.getProfile();
        if (widget.existingListing == null) {
          _ownerPhoneCtrl.text = (profile.phone ?? '').trim();
          _ownerCityAreaCtrl.text = (profile.placeLive ?? profile.from ?? '')
              .trim();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _isLoggedIn = hasSession;
      _isCheckingAuth = false;
    });
  }

  Future<void> _resolveBangladeshCountry() async {
    try {
      final country = await _repository.fetchBangladeshCountry();
      if (!mounted) return;
      setState(() {
        _bangladeshCountry = country;
        _countryError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _countryError = 'Could not resolve Bangladesh country. Tap retry.',
      );
    }
  }

  // ─── GPS ─────────────────────────────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gpsLoading = true;
      _gpsText = null;
    });
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (!mounted) return;
        setState(() {
          _gpsLoading = false;
          _gpsText = 'Location services are disabled. Please enable GPS.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _gpsLoading = false;
            _gpsText = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _gpsLoading = false;
          _gpsText =
              'Permissions permanently denied. Please enable in Settings.';
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'Location permission has been permanently denied. '
              'Please open App Settings to grant permission manually.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 6));

      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _gpsLoading = false;
        _gpsText =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsLoading = false;
        _gpsText = 'Failed to capture GPS coordinates ($e).';
      });
    }
  }

  // ─── media ───────────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    if (_pickingMedia) return;
    _pickingMedia = true;
    try {
      final list = await _picker.pickMultiImage(imageQuality: 90, limit: 8);
      if (list.isEmpty) return;
      if (!mounted) return;

      final edited = await Navigator.of(context).push<ImageEditResult>(
        MaterialPageRoute(
          builder: (_) => ImageEditorScreen(
            files: list.map((x) => File(x.path)).toList(),
            initialIndex: 0,
          ),
        ),
      );
      if (edited == null || !mounted) return;

      final items = edited.files.map(AdoptionDraftMediaItem.image).toList();
      setState(() {
        _mediaItems.addAll(items);
      });
    } finally {
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_pickingMedia) return;
    _pickingMedia = true;
    try {
      final x = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (x == null) return;
      if (!mounted) return;
      final edited = await Navigator.of(context).push<VideoEditResult>(
        MaterialPageRoute(builder: (_) => VideoEditScreen(file: File(x.path))),
      );
      if (edited == null) return;

      final item = await _buildVideoDraftItem(edited);
      if (!mounted) return;
      setState(() {
        _mediaItems.add(item);
      });
    } finally {
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  void _removeMedia(int index) {
    if (index < 0 || index >= _mediaItems.length) return;
    setState(() => _mediaItems.removeAt(index));
  }

  Future<File?> _resolveMediaFileForEdit(AdoptionDraftMediaItem item) async {
    // Try local file first
    if (item.file.path.isNotEmpty && item.file.existsSync()) {
      return item.file;
    }

    // If no local file but URL exists, download to temp cache
    if (item.url != null && item.url!.isNotEmpty) {
      try {
        final http.Client httpClient = http.Client();
        final response = await httpClient
            .get(Uri.parse(item.url!))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final fileName =
              '${item.id}_${DateTime.now().millisecondsSinceEpoch}${item.isVideo ? '.mp4' : '.jpg'}';
          final cachedFile = File('${tempDir.path}/$fileName');
          await cachedFile.writeAsBytes(response.bodyBytes, flush: true);
          return cachedFile;
        }
      } catch (e) {
        debugPrint('Error downloading media for edit: $e');
      }
    }

    return null;
  }

  Future<void> _editMediaAtIndex(int index) async {
    if (index < 0 || index >= _mediaItems.length) return;
    if (_editingIndexes.contains(index)) return;
    _editingIndexes.add(index);
    try {
      final item = _mediaItems[index];

      // Resolve media file: try local, then download from URL
      final fileToEdit = await _resolveMediaFileForEdit(item);
      if (fileToEdit == null) {
        if (mounted) {
          _showSnack('Media file not found. Please select it again.');
        }
        return;
      }

      if (item.isVideo) {
        final edited = await Navigator.of(context).push<VideoEditResult>(
          MaterialPageRoute(builder: (_) => VideoEditScreen(file: fileToEdit)),
        );
        if (edited == null || !mounted) return;
        final updatedItem = await _buildVideoDraftItem(
          edited,
          existingId: item.id,
        );
        if (!mounted) return;
        setState(
          () => _mediaItems[index] = updatedItem.copyWith(
            uploadState: AdoptionDraftMediaUploadState.local,
            progress: 0,
            clearMediaId: true,
            url: null,
          ),
        );
        return;
      }

      // Edit only the tapped image — pass single file, update only that slot.
      final edited = await Navigator.of(context).push<ImageEditResult>(
        MaterialPageRoute(
          builder: (_) =>
              ImageEditorScreen(files: [fileToEdit], initialIndex: 0),
        ),
      );
      if (edited == null || !mounted) return;
      if (edited.files.isNotEmpty) {
        setState(() {
          _mediaItems[index] = AdoptionDraftMediaItem.image(edited.files.first)
              .copyWith(
                uploadState: AdoptionDraftMediaUploadState.local,
                progress: 0,
                clearMediaId: true,
                url: null,
              );
        });
      }
    } finally {
      _editingIndexes.remove(index);
    }
  }

  Future<AdoptionDraftMediaItem> _buildVideoDraftItem(
    VideoEditResult edited, {
    String? existingId,
  }) async {
    File? thumb;
    try {
      thumb = edited.coverTimestampMs != null
          ? await VideoCompress.getFileThumbnail(
              edited.file.path,
              quality: 60,
              position: edited.coverTimestampMs!,
            )
          : await VideoCompress.getFileThumbnail(edited.file.path, quality: 50);
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
    }

    if (existingId != null) {
      return AdoptionDraftMediaItem(
        id: existingId,
        file: edited.file,
        type: 'VIDEO',
        thumbnail: thumb,
        trimStartMs: edited.trimStartMs,
        trimEndMs: edited.trimEndMs,
        mute: edited.mute,
        volume: edited.volume,
        aspectRatio: edited.aspectRatio,
        quality: edited.quality,
        coverTimestampMs: edited.coverTimestampMs,
      );
    }

    return AdoptionDraftMediaItem.video(
      file: edited.file,
      thumbnail: thumb,
      trimStartMs: edited.trimStartMs,
      trimEndMs: edited.trimEndMs,
      mute: edited.mute,
      volume: edited.volume,
      aspectRatio: edited.aspectRatio,
      quality: edited.quality,
      coverTimestampMs: edited.coverTimestampMs,
    );
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          viewInsets + 88,
        ),
      ),
    );
  }

  void _clearTransientUploadUi() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _updateMediaItemById(
    String itemId,
    AdoptionDraftMediaItem Function(AdoptionDraftMediaItem current) transform,
  ) {
    final index = _mediaItems.indexWhere((item) => item.id == itemId);
    if (index < 0 || !mounted) return;
    setState(() {
      _mediaItems[index] = transform(_mediaItems[index]);
    });
  }

  Future<int> _uploadSingleMedia(AdoptionDraftMediaItem item) async {
    if (item.uploadComplete && item.mediaId != null) {
      return item.mediaId!;
    }

    final filePath = item.file.path;
    final fileExists =
        filePath.isNotEmpty &&
        item.file.existsSync() &&
        item.file.lengthSync() > 0;
    if (!fileExists) {
      throw Exception(
        'Media file is missing or empty: ${filePath.isEmpty ? "(unknown)" : filePath.split(Platform.isWindows ? "\\" : "/").last}. Please re-pick the media and try again.',
      );
    }

    // Compress video before upload
    File fileToUpload = item.file;
    if (item.isVideo) {
      _updateMediaItemById(
        item.id,
        (current) => current.copyWith(
          uploadState: AdoptionDraftMediaUploadState.uploading,
          progress: 0,
          clearErrorMessage: true,
        ),
      );
      try {
        final info = await VideoCompress.compressVideo(
          item.file.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: !item.mute,
        );
        if (info?.file != null && info!.file!.existsSync()) {
          fileToUpload = info.file!;
        }
      } catch (e) {
        debugPrint(
          '[AdoptionUpload] Video compression failed, uploading original: $e',
        );
        // fall through to upload original
      }
    }

    _updateMediaItemById(
      item.id,
      (current) => current.copyWith(
        uploadState: AdoptionDraftMediaUploadState.uploading,
        progress: 0,
        clearErrorMessage: true,
      ),
    );

    final fileSize = item.file.lengthSync();
    final fileSizeMb = fileSize / (1024 * 1024);
    final showNotification = item.isVideo && fileSizeMb >= 50;

    if (showNotification) {
      await _showUploadNotification(
        'Uploading adoption ${item.isVideo ? 'video' : 'photo'}',
        'Starting upload...',
      );
    }

    try {
      final uploaded = await _postsDs.uploadMediaDetailedWithProgress(
        fileToUpload,
        onProgress: (sentBytes, totalBytes) {
          if (totalBytes <= 0) return;
          final progress = sentBytes / totalBytes;
          final progressPercent = (progress * 100).round();
          _updateMediaItemById(
            item.id,
            (current) => current.copyWith(
              uploadState: AdoptionDraftMediaUploadState.uploading,
              progress: progress.clamp(0, 1).toDouble(),
              clearErrorMessage: true,
            ),
          );
          if (showNotification) {
            _updateUploadNotification(
              'Uploading adoption ${item.isVideo ? 'video' : 'photo'}',
              '$progressPercent% complete',
              progress: progressPercent,
            );
          }
        },
        listingId: widget.existingListing?.id,
        draftId: item.id,
        uploadContext: 'adoption',
        trimStartMs: item.isVideo ? item.trimStartMs : null,
        trimEndMs: item.isVideo ? item.trimEndMs : null,
        mute: item.isVideo ? item.mute : null,
        volume: item.isVideo ? item.volume : null,
        coverTimestampMs: item.isVideo ? item.coverTimestampMs : null,
        aspectRatio: item.isVideo ? item.aspectRatio : null,
        quality: item.isVideo ? item.quality : null,
      );
      _updateMediaItemById(
        item.id,
        (current) => current.copyWith(
          mediaId: uploaded.id,
          uploadState: AdoptionDraftMediaUploadState.uploaded,
          progress: 1,
          url: uploaded.previewUrl,
          clearErrorMessage: true,
        ),
      );
      if (showNotification) {
        await _showUploadNotification(
          'Upload complete',
          'Your adoption ${item.isVideo ? 'video' : 'photo'} is ready',
        );
      }
      return uploaded.id;
    } catch (error) {
      final message = _friendlyError(error);
      _updateMediaItemById(
        item.id,
        (current) => current.copyWith(
          uploadState: AdoptionDraftMediaUploadState.failed,
          progress: 0,
          errorMessage: message,
          clearMediaId: true,
        ),
      );
      if (showNotification) {
        await _showUploadNotification('Upload failed', message);
      }
      rethrow;
    }
  }

  Future<void> _retryMediaUpload(int index) async {
    if (index < 0 || index >= _mediaItems.length) return;
    final item = _mediaItems[index];
    if (item.isUploading) return;
    _clearTransientUploadUi();
    try {
      await _uploadSingleMedia(_mediaItems[index]);
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error));
    }
  }

  Future<List<int>> _ensureMediaUploaded() async {
    final ids = <int>[];
    final failures = <String>[];
    for (final item in List<AdoptionDraftMediaItem>.from(_mediaItems)) {
      if (item.uploadComplete && item.mediaId != null) {
        ids.add(item.mediaId!);
        continue;
      }
      try {
        ids.add(await _uploadSingleMedia(item));
      } catch (_) {
        final refreshed = _mediaItems.firstWhere(
          (entry) => entry.id == item.id,
          orElse: () => item,
        );
        failures.add(refreshed.errorMessage ?? 'Upload failed.');
      }
    }
    if (failures.isNotEmpty) {
      throw Exception(failures.first);
    }
    return ids;
  }

  // ─── validation ──────────────────────────────────────────────────────────

  String? _validateSection(int section) {
    switch (section) {
      case 0: // Basic Info
        if (_nameCtrl.text.trim().isEmpty) return 'Pet name is required.';
        if (_species.isEmpty) return 'Species is required.';
        if (!_isAgeValid)
          return 'Age is required (at least one value must be > 0).';
        if (_selectedBreedName == null || _selectedBreedName!.isEmpty)
          return 'Breed is required.';
        if (_selectedBreedName == 'Other' &&
            _breedFallbackCtrl.text.trim().isEmpty) {
          return 'Please specify the custom breed.';
        }
        if (_gender == 'UNKNOWN' || _gender.isEmpty)
          return 'Gender is required.';
        if (_selectedSize == null ||
            _selectedSize == 'Unknown' ||
            _selectedSize!.isEmpty) {
          return 'Size is required.';
        }
        if (_selectedColors.isEmpty) return 'At least one color is required.';
        if (_selectedColors.contains('Other') &&
            _colorFallbackCtrl.text.trim().isEmpty) {
          return 'Please specify the custom color.';
        }
        return null;
      case 1: // Story
        if (_descCtrl.text.trim().isEmpty) return 'Please add a story.';
        if (_reasonCtrl.text.trim().isEmpty)
          return 'Please add an adoption reason.';
        return null;
      case 3: // Location
        if (_bangladeshCountry == null) return 'Country lookup failed. Retry.';
        if (_ownerPhoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '').length <
            7) {
          return 'Owner mobile number is required.';
        }
        if (_ownerCityAreaCtrl.text.trim().isEmpty) {
          return 'Owner city or area is required.';
        }
        if (_pickupNotesCtrl.text.trim().length < 4) {
          return 'Please add pickup or meeting location notes.';
        }
        return null;
      default:
        return null;
    }
  }

  bool _validateAll() {
    bool valid = true;
    setState(() => _sectionErrors.clear());
    for (int i = 0; i < 5; i++) {
      final err = _validateSection(i);
      if (err != null) {
        _sectionErrors[i] = err;
        valid = false;
      }
    }
    return valid;
  }

  bool _validateAllSilently() {
    for (int i = 0; i < 5; i++) {
      if (_validateSection(i) != null) return false;
    }
    return true;
  }

  // ─── navigation ──────────────────────────────────────────────────────────

  void _goToStep(int index) {
    if (_stepIndex == _AdoptionStep.basicInfo.index &&
        index != _AdoptionStep.basicInfo.index) {
      _clearTransientUploadUi();
    }
    // Dismiss any upload-error snackbar from the previous step.
    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _stepIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _tryGoToStep(int index) {
    if (index <= _stepIndex) {
      _goToStep(index);
      return;
    }

    final err = _validateSection(_stepIndex);
    setState(() => _sectionErrors[_stepIndex] = err);
    if (err != null) {
      _showSnack(err);
      return;
    }

    _goToStep(index);
  }

  void _next() {
    if (_stepIndex < _AdoptionStep.values.length - 1) {
      _tryGoToStep(_stepIndex + 1);
    }
  }

  void _back() {
    if (_stepIndex > 0) _goToStep(_stepIndex - 1);
  }

  // ─── build payload ───────────────────────────────────────────────────────

  AdoptionListingFormPayload _buildPayload({List<int> mediaIds = const []}) {
    final resolvedMediaIds = mediaIds.isNotEmpty
        ? mediaIds
        : _mediaItems
              .map((item) => item.mediaId)
              .whereType<int>()
              .toList(growable: false);
    final ageText = getFormattedAge();
    final dob = DateTime.now().subtract(
      Duration(
        days:
            ((_ageYears ?? 0) * 365.25 +
                    (_ageMonths ?? 0) * 30.4375 +
                    (_ageDays ?? 0))
                .round(),
      ),
    );

    return AdoptionListingFormPayload(
      name: _nameCtrl.text.trim(),
      species: _species,
      breed: getBreedValue(),
      ageText: ageText,
      ageYears: _ageYears,
      ageMonths: _ageMonths,
      ageDays: _ageDays,
      totalAgeDays:
          ((_ageYears ?? 0) * 365 + (_ageMonths ?? 0) * 30.4 + (_ageDays ?? 0))
              .round(),
      approximateDateOfBirth: dob.toIso8601String(),
      gender: _gender,
      sizeText: _selectedSize ?? 'Unknown',
      colorText: getColorValue(),
      description: _descCtrl.text.trim(),
      adoptionReason: _reasonCtrl.text.trim(),
      vaccinated: _vaccinated,
      dewormed: _dewormed,
      neutered: _neutered,
      microchipped: _microchipped,
      healthInfo: _healthCtrl.text.trim(),
      ownerContactPhone: _ownerPhoneCtrl.text.trim(),
      ownerWhatsappPhone: _ownerWhatsappCtrl.text.trim(),
      ownerCityAreaText: _ownerCityAreaCtrl.text.trim(),
      pickupLocationNotes: _pickupNotesCtrl.text.trim(),
      countryId: _bangladeshCountry!.id,
      bdDivisionId: _selDivision?.id,
      bdDistrictId: _selDistrict?.id,
      bdUpazilaId: _selUpazila?.id,
      bdAreaId: _selArea?.id,
      serviceAreaType: _serviceAreaType,
      allowInternationalAdoption: _allowIntl,
      customServiceAreasText: _customAreasCtrl.text,
      serviceAreaNotes: _areaNotesCtrl.text.trim(),
      previousPetExperienceRequired: _prevPetExp,
      familyApprovalRequired: _familyApproval,
      canProvideVetCare: _vetCare,
      noResaleAgreement: _noResale,
      followUpAgreement: _followUp,
      minimumIncomeRange: _minIncomeCtrl.text.trim(),
      maximumIncomeRange: _maxIncomeCtrl.text.trim(),
      adopterConditionNote: _conditionNoteCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      mediaIds: resolvedMediaIds,
    );
  }

  // ─── save draft ──────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    if (_isSavingDraft || _bangladeshCountry == null) return;
    setState(() => _isSavingDraft = true);
    try {
      List<int> mediaIds = const [];
      if (_mediaItems.isNotEmpty) {
        setState(() => _mediaUploading = true);
        mediaIds = await _ensureMediaUploaded();
        if (mounted) setState(() => _mediaUploading = false);
      }
      final payload = _buildPayload(mediaIds: mediaIds);
      if (widget.existingListing != null) {
        await _repository.updateAdoptionListing(
          widget.existingListing!.id,
          payload,
          submitNow: false,
        );
      } else {
        await _repository.createAdoptionListing(payload, submitNow: false);
      }
      if (!mounted) return;
      _showSnack('Draft saved successfully.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _mediaUploading = false;
        });
      }
    }
  }

  // ─── open preview ─────────────────────────────────────────────────────────

  Future<void> _openPreview() async {
    if (!_validateAll()) {
      final firstBad = (_sectionErrors.keys.toList()..sort()).first;
      _goToStep(firstBad);
      _showSnack(_sectionErrors[firstBad] ?? 'Please fix form errors.');
      return;
    }

    // Upload media before navigating to preview
    List<int> mediaIds = const [];
    if (_mediaItems.isNotEmpty) {
      setState(() => _mediaUploading = true);
      try {
        mediaIds = await _ensureMediaUploaded();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _mediaUploading = false;
        });
        _showSnack(_friendlyError(e));
        return;
      }
      if (mounted) setState(() => _mediaUploading = false);
    }

    final payload = _buildPayload(mediaIds: mediaIds);
    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdoptionListingPreviewScreen(
          payload: payload,
          repository: _repository,
          localMedia: List.of(_mediaItems),
          existingListingId: widget.existingListing?.id,
        ),
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _publishListing() async {
    if (_bangladeshCountry == null) {
      _showSnack('Country lookup failed. Please retry.');
      return;
    }
    // Block only on failed uploads or invalid form — pending (local) items are uploaded below.
    if (_hasFailedUploads) {
      _showSnack('Retry or remove failed media before publishing.');
      return;
    }
    if (_hasIncompleteRequiredFields) {
      _showSnack('Complete the required listing fields before publishing.');
      return;
    }
    if (_hasActiveUploads || _isSavingDraft || _mediaUploading) return;

    update(() => _isSavingDraft = true);
    try {
      List<int> mediaIds = const [];
      if (_mediaItems.isNotEmpty) {
        update(() => _mediaUploading = true);
        mediaIds = await _ensureMediaUploaded();
        if (mounted) update(() => _mediaUploading = false);
      }
      final payload = _buildPayload(mediaIds: mediaIds);
      if (widget.existingListing != null) {
        await _repository.updateAdoptionListing(
          widget.existingListing!.id,
          payload,
          submitNow: true,
        );
      } else {
        await _repository.createAdoptionListing(payload, submitNow: true);
      }
      if (!mounted) return;
      _showSnack(
        widget.existingListing != null
            ? 'Your adoption listing has been updated.'
            : 'Your adoption listing is now public.',
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) {
        update(() {
          _isSavingDraft = false;
          _mediaUploading = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('Token not found')) return 'Please sign in again.';
    if (raw.contains('Validation error'))
      return 'Some fields are invalid. Please review.';
    return raw.isEmpty ? 'Could not save listing right now.' : raw;
  }

  Future<void> _showUploadNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'adoption_uploads',
        'Adoption Media Uploads',
        channelDescription: 'Notifications for adoption listing media uploads',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        _uploadNotificationId,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('[Adoption] Failed to show notification: $e');
    }
  }

  Future<void> _updateUploadNotification(
    String title,
    String body, {
    int progress = 0,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'adoption_uploads',
        'Adoption Media Uploads',
        channelDescription: 'Notifications for adoption listing media uploads',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: progress < 100,
        progress: 100,
        indeterminate: progress <= 0,
        showProgress: true,
      );
      final notificationDetails = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        _uploadNotificationId,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('[Adoption] Failed to update notification: $e');
    }
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isLoggedIn) {
      return _LoginGate(onBack: () => Navigator.of(context).maybePop());
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.existingListing != null
              ? 'Edit Adoption Listing'
              : 'Create Adoption Listing',
        ),
        centerTitle: false,
        actions: [
          if (_isSavingDraft || _mediaUploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _bangladeshCountry != null ? _saveDraft : null,
              child: const Text('Save Draft'),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _StepIndicator(
              steps: _AdoptionStep.values.map((s) => s.label).toList(),
              current: _stepIndex,
              sectionErrors: _sectionErrors,
              onTap: _tryGoToStep,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _PageBasicInfo(this),
                    _PageStory(this),
                    _PageHealth(this),
                    _PageLocation(this),
                    _PageConditions(this),
                    _PageReview(this),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(state: this),
    );
  }
}

// ─────────────────────────────── Step Indicator ──────────────────────────────

class _StepIndicator extends StatefulWidget {
  final List<String> steps;
  final int current;
  final Map<int, String?> sectionErrors;
  final void Function(int) onTap;

  const _StepIndicator({
    required this.steps,
    required this.current,
    required this.sectionErrors,
    required this.onTap,
  });

  @override
  State<_StepIndicator> createState() => _StepIndicatorState();
}

class _StepIndicatorState extends State<_StepIndicator> {
  late final ScrollController _scrollController;
  late final List<GlobalKey> _chipKeys;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chipKeys = List<GlobalKey>.generate(
      widget.steps.length,
      (_) => GlobalKey(),
    );
  }

  @override
  void didUpdateWidget(covariant _StepIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _chipKeys[widget.current].currentContext;
        if (context != null) {
          final alignment = widget.current == 0
              ? 0.0
              : widget.current == widget.steps.length - 1
              ? 1.0
              : 0.5;
          Scrollable.ensureVisible(
            context,
            alignment: alignment,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${widget.current + 1} of ${widget.steps.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  letterSpacing: 0.5,
                ),
              ),
              Expanded(
                child: Text(
                  widget.steps[widget.current],
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: SizedBox(
            height: 42,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: widget.steps.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final isCurrent = index == widget.current;
                final isDone = index < widget.current;
                final hasError = widget.sectionErrors[index] != null;
                final bg = hasError
                    ? cs.errorContainer
                    : isCurrent
                    ? cs.primary
                    : isDone
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest;
                final fg = hasError
                    ? cs.onErrorContainer
                    : isCurrent
                    ? cs.onPrimary
                    : isDone
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant;

                return GestureDetector(
                  key: _chipKeys[index],
                  onTap: () => widget.onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isCurrent ? cs.primary : cs.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.steps[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

// ─────────────────────────────── Bottom Bar ──────────────────────────────────

class _BottomBar extends StatelessWidget {
  final _CreateAdoptionListingScreenState state;
  const _BottomBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final isFirst = state._stepIndex == 0;
    final isConditions = state._stepIndex == _AdoptionStep.conditions.index;
    final isPreview = state._stepIndex == _AdoptionStep.preview.index;
    final publishBlockReason = state._publishBlockReason;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isPreview && publishBlockReason != null) ...[
                Text(
                  publishBlockReason,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  if (!isFirst)
                    OutlinedButton(
                      onPressed: state._back,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (isPreview) ...[
                    FilledButton.icon(
                      onPressed: state._canPublishNow
                          ? () => state._publishListing()
                          : null,
                      icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                      label: const Text('Publish Now'),
                    ),
                  ] else if (isConditions) ...[
                    FilledButton(
                      onPressed: state._openPreview,
                      child: state._mediaUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Preview Listing'),
                    ),
                  ] else
                    FilledButton(
                      onPressed:
                          (state._stepIndex == 0 && !state._isBasicInfoComplete)
                          ? null
                          : state._next,
                      child: const Text('Next'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _publishFromPreview(BuildContext context) async {
    // Preview screen handles publish — this bar is a fallback shown on page 5
    // but actual publish is triggered from AdoptionListingPreviewScreen.
    // This step index should not reach here normally.
    // Navigate forward to preview screen directly if somehow we land on page 5 via step indicator.
  }
}

// ─────────────────────────────── Page helpers ────────────────────────────────

Widget _field(
  TextEditingController ctrl,
  String label, {
  String? hint,
  int maxLines = 1,
  TextInputType? keyboard,
  String? Function(String?)? validator,
  void Function(String)? onChanged,
}) {
  return TextFormField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboard,
    validator: validator,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    ),
  );
}

EdgeInsets _stepPagePadding(BuildContext context) {
  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
  return EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.xl + keyboardInset + 88,
  );
}

Widget _sectionLabel(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: AppTypography.caption(context).copyWith(
        color: context.colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );
}

Widget _divider() => const SizedBox(height: AppSpacing.md);

// ─────────────────────────────── Page 0: Basic Info ──────────────────────────

class _PageBasicInfo extends StatelessWidget {
  final _CreateAdoptionListingScreenState s;
  const _PageBasicInfo(this.s);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return SingleChildScrollView(
      padding: _stepPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s._sectionErrors[0] != null) _ErrorBanner(s._sectionErrors[0]!),
          _sectionLabel(context, 'PET DETAILS'),
          _field(
            s._nameCtrl,
            'Pet name *',
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Pet name is required.' : null,
            onChanged: (v) => s.update(() {}),
          ),
          _divider(),

          // Species
          DropdownButtonFormField<String>(
            value: s._species,
            isExpanded: true,
            style: TextStyle(fontSize: 14, color: cs.onSurface),
            decoration: const InputDecoration(
              labelText: 'Species *',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            items: _speciesLabels.entries.map((e) {
              return DropdownMenuItem(
                value: e.key,
                child: Text(
                  e.value,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              s.update(() {
                s._species = v;
                s._selectedBreedName = null;
              });
              s._syncTypeToSpecies(v);
            },
          ),
          _divider(),

          // Breed Dropdown
          if (s._loadingBreeds)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else
            DropdownButtonFormField<String>(
              value: s._selectedBreedName,
              isExpanded: true,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
              decoration: const InputDecoration(
                labelText: 'Breed *',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Breed is required.' : null,
              items: s.getBreedOptions().map((bName) {
                return DropdownMenuItem(
                  value: bName,
                  child: Text(
                    bName,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => s.update(() {
                s._selectedBreedName = v;
              }),
            ),

          if (s._selectedBreedName == 'Other') ...[
            _divider(),
            _field(
              s._breedFallbackCtrl,
              'Custom Breed *',
              hint: 'e.g. Siamese mix, Persian longhair',
              validator: (v) =>
                  (s._selectedBreedName == 'Other' && (v ?? '').trim().isEmpty)
                  ? 'Please specify the custom breed.'
                  : null,
              onChanged: (v) => s.update(() {}),
            ),
          ],
          _divider(),

          // Structured Age Row
          Text(
            'Age *',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: s._ageYears,
                  isExpanded: true,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Years',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  items: List.generate(21, (i) => i).map((val) {
                    return DropdownMenuItem(value: val, child: Text('$val'));
                  }).toList(),
                  onChanged: (v) => s.update(() => s._ageYears = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: s._ageMonths,
                  isExpanded: true,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Months',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  items: List.generate(12, (i) => i).map((val) {
                    return DropdownMenuItem(value: val, child: Text('$val'));
                  }).toList(),
                  onChanged: (v) => s.update(() => s._ageMonths = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: s._ageDays,
                  isExpanded: true,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Days',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  items: List.generate(31, (i) => i).map((val) {
                    return DropdownMenuItem(value: val, child: Text('$val'));
                  }).toList(),
                  onChanged: (v) => s.update(() => s._ageDays = v),
                ),
              ),
            ],
          ),
          if (!s._isAgeValid && s._sectionErrors[0] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Age is required (at least one value must be > 0)',
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ),
          _divider(),

          // Gender & Size Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: s._gender,
                  isExpanded: true,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Gender *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v == 'UNKNOWN')
                      ? 'Gender is required.'
                      : null,
                  items: _genderLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    s.update(() => s._gender = v);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: s._selectedSize,
                  isExpanded: true,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Size *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v == 'Unknown' || v.isEmpty)
                      ? 'Size is required.'
                      : null,
                  items:
                      [
                        'Toy',
                        'Small',
                        'Medium',
                        'Large',
                        'Extra Large',
                        'Unknown',
                      ].map((val) {
                        return DropdownMenuItem(value: val, child: Text(val));
                      }).toList(),
                  onChanged: (v) => s.update(() => s._selectedSize = v),
                ),
              ),
            ],
          ),
          _divider(),

          // Colors multi-select wrap
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Colors *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    [
                      'Black',
                      'White',
                      'Brown',
                      'Golden',
                      'Grey',
                      'Orange/Ginger',
                      'Cream',
                      'Mixed',
                      'Spotted',
                      'Striped',
                      'Other',
                    ].map((color) {
                      final isSelected = s._selectedColors.contains(color);
                      return FilterChip(
                        label: Text(
                          color,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          s.update(() {
                            if (selected) {
                              s._selectedColors.add(color);
                            } else {
                              s._selectedColors.remove(color);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              if (s._selectedColors.isEmpty && s._sectionErrors[0] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'At least one color is required.',
                    style: TextStyle(color: cs.error, fontSize: 12),
                  ),
                ),
              if (s._selectedColors.contains('Other')) ...[
                const SizedBox(height: AppSpacing.sm),
                _field(
                  s._colorFallbackCtrl,
                  'Custom Color *',
                  hint: 'e.g. Calico, Blue-merle',
                  validator: (v) =>
                      (s._selectedColors.contains('Other') &&
                          (v ?? '').trim().isEmpty)
                      ? 'Please specify the custom color.'
                      : null,
                  onChanged: (v) => s.update(() {}),
                ),
              ],
            ],
          ),

          _divider(),
          _divider(),
          _sectionLabel(context, 'PHOTOS & VIDEO'),
          _MediaSection(s: s),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Page 1: Story ───────────────────────────────

class _PageStory extends StatelessWidget {
  final _CreateAdoptionListingScreenState s;
  const _PageStory(this.s);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: _stepPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s._sectionErrors[1] != null) _ErrorBanner(s._sectionErrors[1]!),
          _sectionLabel(context, 'PET STORY'),
          Text(
            'Help adopters connect with your pet. A good story increases adoption chances.',
            style: AppTypography.caption(
              context,
            ).copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          _field(
            s._descCtrl,
            'Story *',
            hint:
                'Tell us about the pet\'s personality, habits, favourite things...',
            maxLines: 6,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Please add a story.' : null,
          ),
          _divider(),
          _sectionLabel(context, 'REASON FOR ADOPTION'),
          _field(
            s._reasonCtrl,
            'Why are you rehoming this pet? *',
            hint: 'Moving abroad, allergy, change in living situation...',
            maxLines: 4,
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Please add an adoption reason.'
                : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Page 2: Health ──────────────────────────────

class _PageHealth extends StatelessWidget {
  final _CreateAdoptionListingScreenState s;
  const _PageHealth(this.s);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: _stepPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, 'HEALTH STATUS'),
          _ToggleTile(
            'Vaccinated',
            s._vaccinated,
            (v) => s.update(() => s._vaccinated = v),
          ),
          _ToggleTile(
            'Dewormed',
            s._dewormed,
            (v) => s.update(() => s._dewormed = v),
          ),
          _ToggleTile(
            'Neutered / spayed',
            s._neutered,
            (v) => s.update(() => s._neutered = v),
          ),
          _ToggleTile(
            'Microchipped',
            s._microchipped,
            (v) => s.update(() => s._microchipped = v),
          ),
          _divider(),
          _sectionLabel(context, 'HEALTH NOTES'),
          _field(
            s._healthCtrl,
            'Current illness or treatment note',
            hint: 'Mention any ongoing medication, conditions, or vet visits.',
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Page 3: Location ────────────────────────────

class _PageLocation extends StatelessWidget {
  final _CreateAdoptionListingScreenState s;
  const _PageLocation(this.s);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return SingleChildScrollView(
      padding: _stepPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s._sectionErrors[3] != null) _ErrorBanner(s._sectionErrors[3]!),

          _sectionLabel(context, 'COUNTRY'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('🇧🇩', style: TextStyle(fontSize: 18)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Bangladesh',
                    style: AppTypography.bodyRegular(
                      context,
                    ).copyWith(color: cs.onSurface),
                  ),
                ),
                if (s._countryError != null)
                  TextButton(
                    onPressed: s._resolveBangladeshCountry,
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
          if (s._countryError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s._countryError!,
                style: TextStyle(color: cs.error, fontSize: 11),
              ),
            ),
          _divider(),

          _sectionLabel(context, 'BD LOCATION'),
          _LocationDropdown<BdDivision>(
            label: 'Division',
            value: s._selDivision,
            items: s._divisions,
            loading: false,
            display: (d) => d.display(),
            onChanged: s._onDivisionChanged,
            valueId: (d) => d.id,
          ),
          _divider(),

          if (s._loadingDistricts)
            const LinearProgressIndicator()
          else
            _LocationDropdown<BdDistrict>(
              label: 'District',
              value: s._selDistrict,
              items: s._districts,
              loading: false,
              display: (d) => d.display(),
              hint: s._selDivision == null ? 'Select division first' : null,
              onChanged: s._districts.isEmpty ? null : s._onDistrictChanged,
              valueId: (d) => d.id,
            ),
          _divider(),

          if (s._loadingUpazilas)
            const LinearProgressIndicator()
          else
            _LocationDropdown<BdUpazila>(
              label: 'Upazila / Thana (optional)',
              value: s._selUpazila,
              items: s._upazilas,
              loading: false,
              display: (u) => u.display(),
              hint: s._selDistrict == null ? 'Select district first' : null,
              onChanged: s._upazilas.isEmpty ? null : s._onUpazilaChanged,
              valueId: (u) => u.id,
            ),
          _divider(),

          if (s._loadingAreas)
            const LinearProgressIndicator()
          else if (s._areas.isNotEmpty)
            _LocationDropdown<BdArea>(
              label: 'Area (optional)',
              value: s._selArea,
              items: s._areas,
              loading: false,
              display: (a) => a.display(),
              onChanged: (a) => s.update(() => s._selArea = a),
              valueId: (a) => a.id,
            ),

          _divider(),
          _sectionLabel(context, 'GPS COORDINATES'),
          _GpsTile(
            loading: s._gpsLoading,
            text: s._gpsText,
            hasFix: s._latitude != null,
            onCapture: s._useCurrentLocation,
          ),

          _divider(),
          _sectionLabel(context, 'OWNER CONTACT'),
          _field(s._ownerPhoneCtrl, 'Mobile number', hint: '01XXXXXXXXX'),
          _divider(),
          _field(
            s._ownerWhatsappCtrl,
            'WhatsApp number (optional)',
            hint: 'Use only if different',
          ),
          _divider(),
          _field(s._ownerCityAreaCtrl, 'City / area'),
          _divider(),
          _field(
            s._pickupNotesCtrl,
            'Pickup or meeting location notes',
            hint: 'Example: Meet near Dhanmondi Lake police box',
            maxLines: 2,
          ),
          _divider(),
          _sectionLabel(context, 'SERVICE AREA'),
          DropdownButtonFormField<String>(
            value: s._serviceAreaType,
            isExpanded: true,
            style: TextStyle(fontSize: 14, color: cs.onSurface),
            decoration: const InputDecoration(
              labelText: 'Where can adopters come from?',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            items: _serviceAreaLabels.entries.map((e) {
              return DropdownMenuItem(
                value: e.key,
                child: Text(
                  e.value,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              s.update(() => s._serviceAreaType = v);
            },
          ),
          _divider(),

          _ToggleTile(
            'Allow international adoption',
            s._allowIntl,
            (v) => s.update(() => s._allowIntl = v),
          ),

          if (s._serviceAreaType == 'CUSTOM_AREAS') ...[
            _divider(),
            _field(
              s._customAreasCtrl,
              'Custom areas',
              hint: 'Dhaka, Chittagong, ...',
              maxLines: 2,
            ),
          ],

          _divider(),
          _field(s._areaNotesCtrl, 'Service area note', maxLines: 2),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Page 4: Conditions ──────────────────────────

class _PageConditions extends StatelessWidget {
  final _CreateAdoptionListingScreenState s;
  const _PageConditions(this.s);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: _stepPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, 'ADOPTER REQUIREMENTS'),
          _ToggleTile(
            'Previous pet experience required',
            s._prevPetExp,
            (v) => s.update(() => s._prevPetExp = v),
          ),
          _ToggleTile(
            'Family approval required',
            s._familyApproval,
            (v) => s.update(() => s._familyApproval = v),
          ),
          _ToggleTile(
            'Must be able to provide vet care',
            s._vetCare,
            (v) => s.update(() => s._vetCare = v),
          ),
          _ToggleTile(
            'No resale / no abandonment agreement',
            s._noResale,
            (v) => s.update(() => s._noResale = v),
          ),
          _ToggleTile(
            'Post-adoption follow-up agreement',
            s._followUp,
            (v) => s.update(() => s._followUp = v),
          ),
          _divider(),
          _sectionLabel(context, 'INCOME RANGE (OPTIONAL)'),
          Row(
            children: [
              Expanded(child: _field(s._minIncomeCtrl, 'Min income')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _field(s._maxIncomeCtrl, 'Max income')),
            ],
          ),
          _divider(),
          _field(s._conditionNoteCtrl, 'Other conditions', maxLines: 3),
          const SizedBox(height: AppSpacing.xl),
          const _ReviewCallout(),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Page 5: Preview ─────────────────────────────

class _PageReview extends StatelessWidget {
  final _CreateAdoptionListingScreenState s;
  const _PageReview(this.s);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final name = s._nameCtrl.text.trim().isEmpty
        ? 'Unnamed pet'
        : s._nameCtrl.text.trim();
    final species = _speciesLabels[s._species] ?? s._species;
    final breed = s.getBreedValue().isEmpty ? '—' : s.getBreedValue();
    final age = s.getFormattedAge().isEmpty ? '—' : s.getFormattedAge();
    final gender = _genderLabels[s._gender] ?? s._gender;
    final division = s._selDivision?.display() ?? '';
    final district = s._selDistrict?.display() ?? '';
    final upazila = s._selUpazila?.display() ?? '';
    final locationParts = [
      upazila,
      district,
      division,
      'Bangladesh',
    ].where((p) => p.isNotEmpty).toList();
    final location = locationParts.join(', ');
    final serviceArea =
        _serviceAreaLabels[s._serviceAreaType] ?? s._serviceAreaType;
    final story = s._descCtrl.text.trim();
    final reason = s._reasonCtrl.text.trim();

    return SingleChildScrollView(
      padding: _stepPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photos / video preview
          if (s._mediaItems.isNotEmpty)
            _ReviewMediaCarousel(items: s._mediaItems)
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      color: cs.onSurfaceVariant,
                      size: 32,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No media added',
                      style: AppTypography.caption(
                        context,
                      ).copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Name + badges
          Text(
            name,
            style: AppTypography.sectionTitle(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(species, cs.primaryContainer, cs.onPrimaryContainer),
              if (breed != '—')
                _Badge(breed, cs.secondaryContainer, cs.onSecondaryContainer),
              _Badge(gender, cs.surfaceContainerHighest, cs.onSurface),
              if (age != '—')
                _Badge(age, cs.surfaceContainerHighest, cs.onSurface),
              if (s._vaccinated)
                _Badge(
                  'Vaccinated',
                  Colors.green.shade50,
                  Colors.green.shade700,
                ),
              if (s._dewormed)
                _Badge('Dewormed', Colors.green.shade50, Colors.green.shade700),
              if (s._neutered)
                _Badge('Neutered', Colors.teal.shade50, Colors.teal.shade700),
              if (s._microchipped)
                _Badge(
                  'Microchipped',
                  Colors.blue.shade50,
                  Colors.blue.shade700,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          _PreviewRow(
            Icons.location_on_outlined,
            location.isEmpty ? 'Bangladesh' : location,
          ),
          _PreviewRow(Icons.map_outlined, 'Service area: $serviceArea'),
          if (s._latitude != null)
            _PreviewRow(
              Icons.my_location_rounded,
              'GPS: ${s._latitude!.toStringAsFixed(4)}, ${s._longitude!.toStringAsFixed(4)}',
            ),
          const SizedBox(height: AppSpacing.md),

          if (story.isNotEmpty) ...[
            Text(
              'Story',
              style: AppTypography.menuTitle(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              story,
              style: AppTypography.bodyRegular(
                context,
              ).copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (reason.isNotEmpty) ...[
            Text(
              'Adoption reason',
              style: AppTypography.menuTitle(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: AppTypography.bodyRegular(
                context,
              ).copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          const Divider(),
          Text(
            'This preview is how your listing will appear to adopters.',
            style: AppTypography.caption(
              context,
            ).copyWith(color: cs.onSurfaceVariant),
          ),
          if (s._publishBlockReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s._publishBlockReason!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: s._canPublishNow ? () => _publish(context) : null,
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: const Text('Publish Now'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => s._goToStep(0),
              child: const Text('Edit listing'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publish(BuildContext context) async {
    await s._publishListing();
  }
}

// ─────────────────────────────── Media Section ───────────────────────────────

class _MediaSection extends StatelessWidget {
  final _CreateAdoptionListingScreenState s;
  const _MediaSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s._mediaItems.isNotEmpty)
          _MediaSectionCarousel(
            items: s._mediaItems,
            onEdit: s._editMediaAtIndex,
            onRemove: s._removeMedia,
            onRetry: s._retryMediaUpload,
          ),

        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: s._mediaUploading ? null : s._pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
              label: const Text('Add Photos'),
            ),
            OutlinedButton.icon(
              onPressed: s._mediaUploading ? null : s._pickVideo,
              icon: const Icon(Icons.videocam_outlined, size: 16),
              label: const Text('Add Video'),
            ),
          ],
        ),
        if (s._mediaItems.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'At least one photo or video is recommended.',
              style: AppTypography.caption(
                context,
              ).copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────── Shared helpers ──────────────────────────────

class _MediaSectionCarousel extends StatelessWidget {
  final List<AdoptionDraftMediaItem> items;
  final Future<void> Function(int index) onEdit;
  final void Function(int index) onRemove;
  final Future<void> Function(int index) onRetry;

  const _MediaSectionCarousel({
    required this.items,
    required this.onEdit,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return _DraftMediaTile(
            item: item,
            onEdit: () => onEdit(index),
            onRemove: () => onRemove(index),
            onRetry: () => onRetry(index),
          );
        },
      ),
    );
  }
}

class _ReviewMediaCarousel extends StatelessWidget {
  final List<AdoptionDraftMediaItem> items;

  const _ReviewMediaCarousel({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PageView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            if (item.isVideo) {
              return _LocalVideoPreview(item: item);
            }
            if (item.url != null && item.url!.isNotEmpty) {
              return Image.network(item.url!, fit: BoxFit.cover);
            }
            return Image.file(item.file, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }
}

class _DraftMediaTile extends StatelessWidget {
  final AdoptionDraftMediaItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const _DraftMediaTile({
    required this.item,
    required this.onEdit,
    required this.onRemove,
    required this.onRetry,
  });

  Widget _buildVideoThumbnail(BuildContext context) {
    final thumb = item.thumbnail;
    final url = item.url;

    final hasValidThumbFile =
        thumb != null && thumb.existsSync() && thumb.lengthSync() > 0;

    if (hasValidThumbFile) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            thumb,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildVideoPlaceholder(
                context,
                label: 'Video preview unavailable',
              );
            },
          ),
          _buildPlayOverlay(),
        ],
      );
    } else if (url != null && url.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildVideoPlaceholder(
                context,
                label: 'Video preview unavailable',
              );
            },
          ),
          _buildPlayOverlay(),
        ],
      );
    } else {
      return _buildVideoPlaceholder(
        context,
        label: 'Preparing video preview...',
      );
    }
  }

  Widget _buildPlayOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black.withValues(alpha: 0.18)),
        const Center(
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
        ),
      ],
    );
  }

  Widget _buildVideoPlaceholder(BuildContext context, {required String label}) {
    final fileName = item.file.path.isEmpty
        ? ''
        : item.file.path.split(Platform.isWindows ? '\\' : '/').last;
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_rounded,
            color: Colors.white70,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 8),
          ),
          if (fileName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 8),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context) {
    final url = item.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder(context, label: 'Image unavailable');
        },
      );
    }

    final fileExists =
        item.file.path.isNotEmpty &&
        item.file.existsSync() &&
        item.file.lengthSync() > 0;
    if (fileExists) {
      return Image.file(
        item.file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder(context, label: 'Image unavailable');
        },
      );
    }

    return _buildImagePlaceholder(context, label: 'Image placeholder');
  }

  Widget _buildImagePlaceholder(BuildContext context, {required String label}) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final statusLabel = switch (item.uploadState) {
      AdoptionDraftMediaUploadState.uploading =>
        'Uploading ${(item.progress * 100).round()}%',
      AdoptionDraftMediaUploadState.uploaded => 'Uploaded',
      AdoptionDraftMediaUploadState.failed => 'Upload failed',
      AdoptionDraftMediaUploadState.local => 'Ready to upload',
    };
    return Stack(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant),
            color: cs.surfaceContainerHighest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: item.isVideo
                ? _buildVideoThumbnail(context)
                : _buildImageThumbnail(context),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!item.isUploading)
                _TinyActionChip(icon: Icons.edit, onTap: onEdit),
              if (!item.isUploading) const SizedBox(width: 4),
              _TinyActionChip(icon: Icons.close, onTap: onRemove),
            ],
          ),
        ),
        if (item.isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.35),
              ),
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(
                  value: item.progress.clamp(0, 1),
                ),
              ),
            ),
          ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: item.isVideo
                  ? Colors.black.withValues(alpha: 0.65)
                  : cs.primary.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.isVideo ? 'Video' : 'Photo',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          left: 6,
          right: 6,
          top: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: item.uploadFailed
                      ? cs.errorContainer.withValues(alpha: 0.95)
                      : Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: item.uploadFailed
                        ? cs.onErrorContainer
                        : Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.uploadFailed) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 24,
                  child: OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: BorderSide(color: cs.error),
                      backgroundColor: cs.surface.withValues(alpha: 0.92),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TinyActionChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyActionChip({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _LocalVideoPreview extends StatefulWidget {
  final AdoptionDraftMediaItem item;

  const _LocalVideoPreview({required this.item});

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;
  Future<void>? _init;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final token = ++_token;

    VideoPlayerController controller;

    // Use uploaded URL if available, otherwise fallback to local file
    if (widget.item.url != null && widget.item.url!.isNotEmpty) {
      controller = VideoPlayerController.network(widget.item.url!);
    } else if (widget.item.file.path.isNotEmpty &&
        widget.item.file.existsSync()) {
      controller = VideoPlayerController.file(widget.item.file);
    } else {
      // No valid source available - show error state
      _controller = null;
      _init = Future.error(Exception('No video source available'));
      return;
    }

    _controller = controller;
    _init = controller
        .initialize()
        .then((_) {
          if (!mounted || token != _token) return;
          controller.setLooping(true);
          controller.pause();
          setState(() {});
        })
        .catchError((_) {});
  }

  @override
  void didUpdateWidget(covariant _LocalVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.file.path != widget.item.file.path) {
      final controller = _controller;
      _controller = null;
      _init = null;
      try {
        controller?.pause();
      } catch (_) {}
      controller?.dispose();
      _initController();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    try {
      controller?.pause();
    } catch (_) {}
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _init == null) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white70),
        ),
      );
    }
    return FutureBuilder<void>(
      future: _init,
      builder: (_, snap) {
        if (snap.hasError) {
          return Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.error_outline, color: Colors.white54, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Video unavailable',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.item.thumbnail != null &&
                  widget.item.thumbnail!.path.isNotEmpty &&
                  widget.item.thumbnail!.existsSync())
                Image.file(widget.item.thumbnail!, fit: BoxFit.cover)
              else
                const ColoredBox(color: Colors.black87),
              Container(color: Colors.black.withValues(alpha: 0.18)),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 68,
                ),
              ),
            ],
          );
        }
        return GestureDetector(
          onTap: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
            setState(() {});
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
              if (!controller.value.isPlaying)
                Container(
                  color: Colors.black.withValues(alpha: 0.22),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 68,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

class _LocationDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final bool loading;
  final String Function(T) display;
  final String? hint;
  final ValueChanged<T?>? onChanged;
  final int Function(T) valueId;

  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.loading,
    required this.display,
    required this.valueId,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const LinearProgressIndicator();
    final cs = Theme.of(context).colorScheme;
    final uniqueItems = _uniqueObjects<T>(items, valueId);
    final selectedValue = _safeObjectSelection<T>(value, uniqueItems, valueId);
    return DropdownButtonFormField<T>(
      value: selectedValue,
      isExpanded: true,
      style: TextStyle(fontSize: 14, color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? (items.isEmpty ? 'No data available' : null),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text(
            '— Not selected —',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...uniqueItems.map(
          (item) => DropdownMenuItem<T>(
            value: item,
            child: Text(
              display(item),
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: uniqueItems.isEmpty ? null : onChanged,
    );
  }
}

class _GpsTile extends StatelessWidget {
  final bool loading;
  final String? text;
  final bool hasFix;
  final VoidCallback onCapture;

  const _GpsTile({
    required this.loading,
    required this.text,
    required this.hasFix,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasFix ? Icons.location_on : Icons.my_location,
            color: hasFix ? cs.primary : cs.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text ?? 'Capture GPS for nearby search (optional)',
              style: AppTypography.caption(
                context,
              ).copyWith(color: hasFix ? cs.primary : cs.onSurfaceVariant),
            ),
          ),
          loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: onCapture,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(hasFix ? 'Update' : 'Capture'),
                ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PreviewRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption(
                context,
              ).copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCallout extends StatelessWidget {
  const _ReviewCallout();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap "Preview Listing" to review before publishing.',
              style: AppTypography.caption(
                context,
              ).copyWith(color: cs.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginGate extends StatelessWidget {
  final VoidCallback onBack;
  const _LoginGate({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Adoption Listing')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 40, color: cs.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sign in required',
                style: AppTypography.sectionTitle(
                  context,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Please sign in to create an adoption listing.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyRegular(
                  context,
                ).copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onBack, child: const Text('Go back')),
            ],
          ),
        ),
      ),
    );
  }
}
