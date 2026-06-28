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
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

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

  // species / breed
  String _species = 'CAT';
  List<AnimalTypeDto> _animalTypes = const [];
  int? _selectedTypeId;
  List<BreedDto> _breeds = const [];
  BreedDto? _selectedBreed;
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
  String? _mediaError;

  // UI
  int _stepIndex = 0;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;
  bool _isSavingDraft = false;

  // section-level validation flags
  final Map<int, String?> _sectionErrors = {};

  // Public wrapper — page sub-widgets call this instead of setState directly
  void update(VoidCallback fn) => setState(fn);

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
    _species = pet.species.toUpperCase();

    _ageCtrl.text = pet.ageLabel == 'Age not specified' ? '' : pet.ageLabel;
    _sizeCtrl.text = pet.sizeText ?? '';
    _colorCtrl.text = pet.colorText ?? '';
    _descCtrl.text = pet.description;

    const prefix = 'Reason for adoption: ';
    if (pet.story.startsWith(prefix)) {
      _reasonCtrl.text = pet.story.substring(prefix.length);
    } else {
      _reasonCtrl.text = pet.story;
    }

    _vaccinated = pet.vaccinated;
    _dewormed = pet.dewormed;
    _neutered = pet.neutered;
    _microchipped = pet.microchipped;
    _healthCtrl.text = pet.healthNotes == 'No health notes available yet.' ? '' : pet.healthNotes;

    _ownerPhoneCtrl.text = pet.ownerContactPhone ?? '';
    _ownerWhatsappCtrl.text = pet.ownerWhatsappPhone ?? '';
    _ownerCityAreaCtrl.text = pet.ownerCityAreaText ?? '';
    _pickupNotesCtrl.text = pet.pickupLocationNotes ?? '';

    _prevPetExp = pet.adopterConditions.contains('Previous pet experience required');
    _familyApproval = pet.adopterConditions.contains('Family approval required');
    _vetCare = pet.adopterConditions.contains('Must be able to provide vet care');
    _noResale = pet.adopterConditions.contains('No resale or abandonment agreement required');
    _followUp = pet.adopterConditions.contains('Post-adoption follow-up agreement required');

    final standardKeys = [
      'Previous pet experience required',
      'Family approval required',
      'Must be able to provide vet care',
      'No resale or abandonment agreement required',
      'Post-adoption follow-up agreement required',
    ];
    final customNotes = pet.adopterConditions.where((c) => !standardKeys.contains(c)).toList();
    if (customNotes.isNotEmpty) {
      _conditionNoteCtrl.text = customNotes.join(', ');
    }

    if (pet.serviceAreaType != null) {
      _serviceAreaType = pet.serviceAreaType!;
    }

    _latitude = pet.latitude;
    _longitude = pet.longitude;
    if (_latitude != null && _longitude != null) {
      _gpsText = '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}';
    }

    for (final m in pet.media) {
      _mediaItems.add(AdoptionDraftMediaItem(
        id: m.id?.toString() ?? UniqueKey().toString(),
        file: File(''),
        type: m.type,
        url: m.displayUrl,
      ));
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
      _selectedBreed = null;
    });
    try {
      final breeds = await _repository.fetchBreedsByType(typeId);
      if (!mounted) return;
      setState(() {
        _breeds = breeds;
        if (widget.existingListing?.breed != null) {
          _selectedBreed = _breeds.cast<BreedDto?>().firstWhere(
                (b) => b!.name.toLowerCase() == widget.existingListing!.breed.toLowerCase(),
                orElse: () => null,
              );
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

  Future<void> _onDivisionChanged(BdDivision? d, {bool prefilling = false}) async {
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

  Future<void> _onDistrictChanged(BdDistrict? d, {bool prefilling = false}) async {
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

  Future<void> _onUpazilaChanged(BdUpazila? u, {bool prefilling = false}) async {
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
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    if (token.isNotEmpty) {
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
      _isLoggedIn = token.isNotEmpty;
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
          _gpsText = 'Permissions permanently denied. Please enable in Settings.';
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
      _mediaError = null;
    });
  }

  Future<void> _pickVideo() async {
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
      _mediaItems.removeWhere((m) => m.isVideo);
      _mediaItems.add(item);
      _mediaError = null;
    });
  }

  void _removeMedia(int index) {
    if (index < 0 || index >= _mediaItems.length) return;
    setState(() => _mediaItems.removeAt(index));
  }

  Future<void> _editMediaAtIndex(int index) async {
    if (index < 0 || index >= _mediaItems.length) return;
    final item = _mediaItems[index];
    if (item.isVideo) {
      final edited = await Navigator.of(context).push<VideoEditResult>(
        MaterialPageRoute(builder: (_) => VideoEditScreen(file: item.file)),
      );
      if (edited == null || !mounted) return;
      final updatedItem = await _buildVideoDraftItem(
        edited,
        existingId: item.id,
      );
      if (!mounted) return;
      setState(() => _mediaItems[index] = updatedItem);
      return;
    }

    final imageItemIndexes = <int>[];
    final imageFiles = <File>[];
    for (int i = 0; i < _mediaItems.length; i++) {
      if (_mediaItems[i].isImage) {
        imageItemIndexes.add(i);
        imageFiles.add(_mediaItems[i].file);
      }
    }
    final imageIndex = imageItemIndexes.indexOf(index);
    if (imageIndex < 0) return;

    final edited = await Navigator.of(context).push<ImageEditResult>(
      MaterialPageRoute(
        builder: (_) =>
            ImageEditorScreen(files: imageFiles, initialIndex: imageIndex),
      ),
    );
    if (edited == null || !mounted) return;
    setState(() {
      for (
        int i = 0;
        i < imageItemIndexes.length && i < edited.files.length;
        i++
      ) {
        _mediaItems[imageItemIndexes[i]] = AdoptionDraftMediaItem.image(
          edited.files[i],
        );
      }
    });
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

  // Upload all picked media and return mediaIds
  Future<List<int>> _uploadMedia() async {
    final ids = <int>[];
    for (final item in _mediaItems) {
      ids.add(
        await _postsDs.uploadMedia(
          item.file,
          trimStartMs: item.isVideo ? item.trimStartMs : null,
          trimEndMs: item.isVideo ? item.trimEndMs : null,
          mute: item.isVideo ? item.mute : null,
          volume: item.isVideo ? item.volume : null,
          coverTimestampMs: item.isVideo ? item.coverTimestampMs : null,
          aspectRatio: item.isVideo ? item.aspectRatio : null,
          quality: item.isVideo ? item.quality : null,
        ),
      );
    }
    return ids;
  }

  // ─── validation ──────────────────────────────────────────────────────────

  String? _validateSection(int section) {
    switch (section) {
      case 0: // Basic Info
        if (_nameCtrl.text.trim().isEmpty) return 'Pet name is required.';
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

  // ─── navigation ──────────────────────────────────────────────────────────

  void _goToStep(int index) {
    setState(() => _stepIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_stepIndex < _AdoptionStep.values.length - 1) {
      final err = _validateSection(_stepIndex);
      setState(() => _sectionErrors[_stepIndex] = err);
      _goToStep(_stepIndex + 1);
    }
  }

  void _back() {
    if (_stepIndex > 0) _goToStep(_stepIndex - 1);
  }

  // ─── build payload ───────────────────────────────────────────────────────

  AdoptionListingFormPayload _buildPayload({List<int> mediaIds = const []}) {
    return AdoptionListingFormPayload(
      name: _nameCtrl.text.trim(),
      species: _species,
      breed: _selectedBreed?.name ?? '',
      ageText: _ageCtrl.text.trim(),
      gender: _gender,
      sizeText: _sizeCtrl.text.trim(),
      colorText: _colorCtrl.text.trim(),
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
      mediaIds: mediaIds,
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
        mediaIds = await _uploadMedia();
        if (mounted) setState(() => _mediaUploading = false);
      }
      final payload = _buildPayload(mediaIds: mediaIds);
      await _repository.createAdoptionListing(payload, submitNow: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  // ─── open preview ─────────────────────────────────────────────────────────

  Future<void> _openPreview() async {
    if (!_validateAll()) {
      final firstBad = (_sectionErrors.keys.toList()..sort()).first;
      _goToStep(firstBad);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_sectionErrors[firstBad] ?? 'Please fix form errors.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Upload media before navigating to preview
    List<int> mediaIds = const [];
    if (_mediaItems.isNotEmpty) {
      setState(() => _mediaUploading = true);
      try {
        mediaIds = await _uploadMedia();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _mediaUploading = false;
          _mediaError =
              'Upload failed: ${e.toString().replaceFirst("Exception: ", "")}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mediaError!),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  String _friendlyError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('Token not found')) return 'Please sign in again.';
    if (raw.contains('Validation error'))
      return 'Some fields are invalid. Please review.';
    return raw.isEmpty ? 'Could not save listing right now.' : raw;
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
      appBar: AppBar(
        title: const Text('Create Adoption Listing'),
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
        child: Column(
          children: [
            _StepIndicator(
              steps: _AdoptionStep.values.map((s) => s.label).toList(),
              current: _stepIndex,
              sectionErrors: _sectionErrors,
              onTap: _goToStep,
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
            _BottomBar(state: this),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Step Indicator ──────────────────────────────

class _StepIndicator extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
        itemCount: steps.length,
        itemBuilder: (context, i) {
          final isCurrent = i == current;
          final hasError = sectionErrors[i] != null;
          final isDone = i < current;
          final color = hasError
              ? cs.error
              : isCurrent
              ? cs.primary
              : isDone
              ? cs.primary.withValues(alpha: 0.55)
              : cs.onSurfaceVariant.withValues(alpha: 0.45);

          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent ? cs.primaryContainer : Colors.transparent,
                border: Border.all(color: color, width: isCurrent ? 1.5 : 1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasError)
                    Icon(Icons.error_outline, size: 13, color: cs.error)
                  else if (isDone)
                    Icon(
                      Icons.check_circle,
                      size: 13,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                  if (hasError || isDone) const SizedBox(width: 4),
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          if (!isFirst)
            OutlinedButton(onPressed: state._back, child: const Text('Back')),
          const Spacer(),
          if (isPreview) ...[
            FilledButton.icon(
              onPressed: state._mediaUploading
                  ? null
                  : () => _publishFromPreview(context),
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
            FilledButton(onPressed: state._next, child: const Text('Next')),
        ],
      ),
    );
  }

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
}) {
  return TextFormField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboard,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    ),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
          ),
          _divider(),

          // Species
          DropdownButtonFormField<String>(
            value: s._species,
            isExpanded: true,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface,
            ),
            decoration: const InputDecoration(
              labelText: 'Species *',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            items: _speciesLabels.entries
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
              s.update(() => s._species = v);
              s._syncTypeToSpecies(v);
            },
          ),
          _divider(),

          // Breed
          if (s._loadingBreeds)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (s._breeds.isNotEmpty)
            DropdownButtonFormField<BreedDto>(
              value: s._selectedBreed,
              isExpanded: true,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface,
              ),
              decoration: const InputDecoration(
                labelText: 'Breed',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<BreedDto>(
                  value: null,
                  child: Text(
                    'Not specified',
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...s._breeds.map(
                  (b) => DropdownMenuItem(
                    value: b,
                    child: Text(
                      b.name,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (b) => s.update(() => s._selectedBreed = b),
            )
          else
            _field(
              s._breedFallbackCtrl,
              'Breed',
              hint: 'Not available for this species',
            ),
          _divider(),

          Row(
            children: [
              Expanded(child: _field(s._ageCtrl, 'Age', hint: '2 years')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _field(s._colorCtrl, 'Color', hint: 'Orange tabby'),
              ),
            ],
          ),
          _divider(),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: s._gender,
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
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
                  onChanged: (v) => s.update(() => s._gender = v ?? s._gender),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _field(
                  s._sizeCtrl,
                  'Size',
                  hint: 'Small / Medium / Large',
                ),
              ),
            ],
          ),

          _divider(),
          _divider(),
          _sectionLabel(context, 'PHOTOS & VIDEO'),
          _MediaSection(s: s),

          if (s._mediaError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s._mediaError!,
              style: TextStyle(color: cs.error, fontSize: 12),
            ),
          ],
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface,
            ),
            decoration: const InputDecoration(
              labelText: 'Where can adopters come from?',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            items: _serviceAreaLabels.entries
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
            onChanged: (v) =>
                s.update(() => s._serviceAreaType = v ?? s._serviceAreaType),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
    final breed = s._selectedBreed?.name ?? '—';
    final age = s._ageCtrl.text.trim().isEmpty ? '—' : s._ageCtrl.text.trim();
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: s._mediaUploading ? null : () => _publish(context),
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
    final state = s;
    if (state._bangladeshCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Country lookup failed. Please retry.')),
      );
      return;
    }
    state.update(() => state._isSavingDraft = true);
    try {
      // Media was already uploaded when navigating to preview via _openPreview.
      // On inline preview (page 5 via step bar), upload now if needed.
      List<int> mediaIds = const [];
      if (state._mediaItems.isNotEmpty) {
        state.update(() => state._mediaUploading = true);
        mediaIds = await state._uploadMedia();
        if (state.mounted) state.update(() => state._mediaUploading = false);
      }
      final payload = state._buildPayload(mediaIds: mediaIds);
      await state._repository.createAdoptionListing(payload, submitNow: true);
      if (!state.mounted) return;
      ScaffoldMessenger.of(state.context).showSnackBar(
        const SnackBar(content: Text('Your adoption listing is now public.')),
      );
      Navigator.of(state.context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!state.mounted) return;
      state.update(() => state._isSavingDraft = false);
      ScaffoldMessenger.of(
        state.context,
      ).showSnackBar(SnackBar(content: Text(state._friendlyError(e))));
    }
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

  const _MediaSectionCarousel({
    required this.items,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
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
              if (item.url != null && item.url!.isNotEmpty) {
                return Image.network(item.url!, fit: BoxFit.cover);
              }
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

  const _DraftMediaTile({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Stack(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant),
            color: cs.surfaceContainerHighest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: item.isVideo
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.thumbnail != null)
                        Image.file(item.thumbnail!, fit: BoxFit.cover)
                      else if (item.url != null && item.url!.isNotEmpty)
                        Image.network(item.url!, fit: BoxFit.cover)
                      else
                        Container(color: Colors.black87),
                      Container(color: Colors.black.withValues(alpha: 0.18)),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  )
                : (item.url != null && item.url!.isNotEmpty)
                    ? Image.network(item.url!, fit: BoxFit.cover)
                    : Image.file(item.file, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TinyActionChip(icon: Icons.edit, onTap: onEdit),
              const SizedBox(width: 4),
              _TinyActionChip(icon: Icons.close, onTap: onRemove),
            ],
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
    final controller = VideoPlayerController.file(widget.item.file);
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
      return const ColoredBox(color: Colors.black87);
    }
    return FutureBuilder<void>(
      future: _init,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.item.thumbnail != null)
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

  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.loading,
    required this.display,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const LinearProgressIndicator();
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      style: TextStyle(
        fontSize: 14,
        color: cs.onSurface,
      ),
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
        ...items.map(
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
      onChanged: items.isEmpty ? null : onChanged,
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
