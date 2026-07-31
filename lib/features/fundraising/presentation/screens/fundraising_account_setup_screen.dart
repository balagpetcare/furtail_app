// ignore_for_file: deprecated_member_use, unused_element, unused_field

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:furtail_app/core/providers/current_user_provider.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:furtail_app/features/common/presentation/providers/bd_location_providers.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/location/presentation/widgets/location_selector_widget.dart';

import 'package:latlong2/latlong.dart';
import 'package:furtail_app/features/location/presentation/location_picker_screen.dart';
import 'package:furtail_app/features/fundraising/data/fundraising_error_mapper.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_json.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_status_views.dart'
    show FundraisingErrorView, FundraisingLoadingView;
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_create_wizard_widgets.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../providers/fundraising_providers.dart';
import '../../data/models/fundraising_models.dart';
import 'fundraising_account_documents_screen.dart';
import 'fundraising_document_preview_screen.dart';

/// Fundraising Account Verification (KYC) screen
/// - User can submit info + upload documents.
/// - Even if status is PENDING, user can still create fundraising posts,
///   but they MUST fill this form + upload docs at least once.
enum _VerificationScreenState {
  loadingAccount,
  firstTimeSetup,
  editingExisting,
  accountLoadError,
}

/// Debug-only sanitized diagnostics for verification-load failures.
/// Never includes tokens, identity values, addresses, document URLs,
/// IPs, ports, or full response bodies — only operation/method/path/status
/// classification and the parsing field/type when relevant.
void _logVerificationDiagnostic({
  required String operation,
  String? method,
  String? path,
  int? statusCode,
  String? backendCode,
  String? dioExceptionType,
  String? parseField,
  String? parseType,
}) {
  if (!kDebugMode) return;
  final parts = <String>[
    'op=$operation',
    if (method != null) 'method=$method',
    if (path != null) 'path=$path',
    if (statusCode != null) 'status=$statusCode',
    if (backendCode != null) 'backendCode=$backendCode',
    if (dioExceptionType != null) 'dioType=$dioExceptionType',
    if (parseField != null) 'parseField=$parseField',
    if (parseType != null) 'parseType=$parseType',
  ];
  debugPrint('[fundraising:verification] ${parts.join(' ')}');
}

void _logErrorDiagnostic(String operation, Object error) {
  if (!kDebugMode) return;
  if (error is ApiClientException) {
    _logVerificationDiagnostic(
      operation: operation,
      statusCode: error.statusCode,
      backendCode: error.code,
    );
  } else if (error is DioException) {
    _logVerificationDiagnostic(
      operation: operation,
      dioExceptionType: error.type.toString(),
    );
  } else if (error is FundraisingAccountParseException) {
    _logVerificationDiagnostic(
      operation: operation,
      parseType: error.runtimeType.toString(),
    );
  } else if (error is TypeError) {
    _logVerificationDiagnostic(operation: operation, parseType: 'TypeError');
  } else {
    _logVerificationDiagnostic(
      operation: operation,
      parseType: error.runtimeType.toString(),
    );
  }
}

class FundraisingAccountSetupScreen extends ConsumerStatefulWidget {
  const FundraisingAccountSetupScreen({
    super.key,
    this.initialAccount,
    this.initialReadiness,
  });

  final FundraisingAccount? initialAccount;
  final FundraisingAccountReadiness? initialReadiness;

  @override
  ConsumerState<FundraisingAccountSetupScreen> createState() =>
      _FundraisingAccountSetupScreenState();
}

class _FundraisingAccountSetupScreenState
    extends ConsumerState<FundraisingAccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _postsDs = PostsRemoteDs();

  String _accountType = 'INDIVIDUAL';

  // Required info
  final _presentAddressCtrl = TextEditingController();
  final _permanentAddressCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();

  final _fullNameCtrl = TextEditingController();

  // IDs
  final _nidCtrl = TextEditingController();
  final _birthRegCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _drivingLicenceCtrl = TextEditingController();

  DateTime? _dob;

  // Location dropdown selections
  int? _divisionId;
  int? _districtId;
  LocationAddressMode? _addressMode;
  int? _cityCorporationId;
  int? _zoneId;
  int? _wardId;
  int? _upazilaId;
  int? _unionId;
  int? _areaId;
  String? _divisionName;
  String? _districtName;
  String? _cityCorporationName;
  String? _zoneName;
  String? _wardName;
  String? _upazilaName;
  String? _unionName;
  String? _areaName;

  // Organization-only fields
  final _orgNameCtrl = TextEditingController();
  final _orgDescCtrl = TextEditingController();
  final _orgWorkTypeCtrl = TextEditingController();

  bool _saving = false;
  // Independent per-document-slot loading state, keyed by document title —
  // uploading/replacing one document (e.g. selfie) must not disable the
  // Upload/Replace/Remove actions on other document slots.
  final Set<String> _busyDocSlots = {};
  bool get _busyDoc => _busyDocSlots.isNotEmpty;
  // Per-slot action ('upload'/'replace'/'remove') while busy, and the last
  // failure message per slot so a failed upload shows an inline Retry
  // instead of only a transient snackbar.
  final Map<String, String> _docSlotAction = {};
  final Map<String, String> _docSlotErrors = {};
  bool _prefilled = false;
  bool _hasUnsavedChanges = false;
  bool _sameAsPresentAddress = false;
  bool _consentGiven = false;
  int _verificationStep = 0;
  String _primaryDocumentType = 'NID';
  _VerificationScreenState _screenState =
      _VerificationScreenState.loadingAccount;
  FundraisingSafeError? _loadError;
  FundraisingAccount? _account;

  // Secondary (non-fatal) load failures: the account fetch itself succeeded,
  // so the form must stay visible with a scoped retry instead of collapsing
  // into the full-page "Verification unavailable" error.
  FundraisingSafeError? _locationCatalogError;
  bool _locationCatalogRetrying = false;
  bool _accountLoadInFlight = false;

  // Global / International fields
  bool _isGlobalMode = false;
  final _countryNameCtrl = TextEditingController();
  final _stateNameCtrl = TextEditingController();
  final _cityNameCtrl = TextEditingController();
  final _addressLineCtrl = TextEditingController();
  double? _latitude;
  double? _longitude;
  String? _formattedAddress;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _presentAddressCtrl.dispose();
    _permanentAddressCtrl.dispose();
    _occupationCtrl.dispose();
    _nidCtrl.dispose();
    _birthRegCtrl.dispose();
    _studentIdCtrl.dispose();
    _passportCtrl.dispose();
    _drivingLicenceCtrl.dispose();
    _orgNameCtrl.dispose();
    _orgDescCtrl.dispose();
    _orgWorkTypeCtrl.dispose();
    _countryNameCtrl.dispose();
    _stateNameCtrl.dispose();
    _cityNameCtrl.dispose();
    _addressLineCtrl.dispose();
    super.dispose();
  }

  void _resetFormState() {
    _prefilled = false;
    _accountType = 'INDIVIDUAL';
    _fullNameCtrl.clear();
    _presentAddressCtrl.clear();
    _permanentAddressCtrl.clear();
    _occupationCtrl.clear();
    _nidCtrl.clear();
    _birthRegCtrl.clear();
    _studentIdCtrl.clear();
    _passportCtrl.clear();
    _drivingLicenceCtrl.clear();
    _dob = null;
    _divisionId = null;
    _districtId = null;
    _addressMode = null;
    _cityCorporationId = null;
    _zoneId = null;
    _wardId = null;
    _upazilaId = null;
    _unionId = null;
    _areaId = null;
    _divisionName = null;
    _districtName = null;
    _cityCorporationName = null;
    _zoneName = null;
    _wardName = null;
    _upazilaName = null;
    _unionName = null;
    _areaName = null;
    _isGlobalMode = false;
    _countryNameCtrl.clear();
    _stateNameCtrl.clear();
    _cityNameCtrl.clear();
    _addressLineCtrl.clear();
    _latitude = null;
    _longitude = null;
    _formattedAddress = null;
    _orgNameCtrl.clear();
    _orgDescCtrl.clear();
    _orgWorkTypeCtrl.clear();
    _hasUnsavedChanges = false;
    _sameAsPresentAddress = false;
    _consentGiven = false;
    _primaryDocumentType = 'NID';
    _verificationStep = 0;
  }

  Future<void> _loadAccount({bool keepVisibleWhileLoading = false}) async {
    // Deduplicate: never let screen init, a manual retry, and a post-save
    // refresh all race the same account request at once.
    if (_accountLoadInFlight) return;
    if (!mounted) return;
    _accountLoadInFlight = true;
    if (!keepVisibleWhileLoading) {
      setState(() {
        _screenState = _VerificationScreenState.loadingAccount;
        _loadError = null;
      });
    }

    FundraisingAccount? account;
    try {
      account = await ref.read(fundraisingMyAccountProvider.future);
    } catch (error) {
      _accountLoadInFlight = false;
      _logErrorDiagnostic('fundraising.account.me', error);
      if (!mounted) return;
      final safeError = mapFundraisingSafeError(error);
      if (safeError.isSessionExpired) {
        // AuthInterceptor already attempts a token refresh transparently;
        // if the error still surfaces here the session is definitively
        // expired. AuthController.forceLogout() flips the global auth
        // state and AuthGate replaces this whole screen with LoginScreen,
        // so keep showing a neutral loading state rather than flashing
        // "Verification unavailable" while that redirect lands.
        setState(() {
          _screenState = _VerificationScreenState.loadingAccount;
        });
        return;
      }
      // Genuine account request failure: full safe error state.
      setState(() {
        _account = null;
        _loadError = safeError;
        _screenState = _VerificationScreenState.accountLoadError;
      });
      return;
    }

    // Account request succeeded (including accountType:null / data:null
    // "first-time setup" cases) — the form must stay visible from here on.
    // Any failure below is secondary and must not collapse the screen.
    if (!mounted) {
      _accountLoadInFlight = false;
      return;
    }
    _resetFormState();
    _prefill(account);

    try {
      final recovery = await ref
          .read(fundraisingVerificationRecoveryServiceProvider)
          .load();
      if (recovery != null) {
        _applyRecovery(recovery);
      } else if (account?.verificationDraftJson != null) {
        _applyRecovery(account!.verificationDraftJson!);
      }
    } catch (error) {
      // Local draft recovery is best-effort only; never block the form.
      _logErrorDiagnostic('fundraising.verification.recovery', error);
    }

    FundraisingSafeError? locationError;
    if (!_isGlobalMode && _divisionId != null) {
      try {
        await _sanitizeRestoredBangladeshSelection();
      } catch (error) {
        _logErrorDiagnostic('fundraising.locations.validate', error);
        locationError = mapFundraisingSafeError(error);
      }
    }

    _accountLoadInFlight = false;
    if (!mounted) return;
    setState(() {
      _account = account;
      _loadError = null;
      _locationCatalogError = locationError;
      _screenState = account == null
          ? _VerificationScreenState.firstTimeSetup
          : _VerificationScreenState.editingExisting;
    });
  }

  Future<void> _retryLocationCatalog() async {
    if (_locationCatalogRetrying) return;
    setState(() => _locationCatalogRetrying = true);
    try {
      await _sanitizeRestoredBangladeshSelection();
      if (!mounted) return;
      setState(() => _locationCatalogError = null);
    } catch (error) {
      _logErrorDiagnostic('fundraising.locations.validate.retry', error);
      if (!mounted) return;
      setState(() => _locationCatalogError = mapFundraisingSafeError(error));
    } finally {
      if (mounted) setState(() => _locationCatalogRetrying = false);
    }
  }

  void _prefill(FundraisingAccount? a) {
    if (_prefilled) return;
    _prefilled = true;

    // Full name is never silently substituted with the account's email —
    // prefill from any previously-saved value, else the authenticated
    // user's real display name (never their email), else leave it blank
    // and require the user to type it in.
    final savedFullName = a?.fullName?.trim() ?? '';
    if (savedFullName.isNotEmpty) {
      _fullNameCtrl.text = savedFullName;
    } else {
      final currentName = ref.read(currentUserProvider).name.trim();
      if (currentName.isNotEmpty && currentName != 'Guest') {
        _fullNameCtrl.text = currentName;
      }
    }

    if (a == null) return;

    _accountType = (a.accountType == null || a.accountType!.isEmpty)
        ? 'INDIVIDUAL'
        : a.accountType!;
    _presentAddressCtrl.text = a.presentAddress ?? '';
    _permanentAddressCtrl.text = a.permanentAddress ?? '';
    _occupationCtrl.text = a.occupation ?? '';
    _primaryDocumentType = a.primaryDocumentType ?? _primaryDocumentType;

    _nidCtrl.text = a.nationalIdNumber ?? '';
    _birthRegCtrl.text = a.birthRegNumber ?? '';
    _studentIdCtrl.text = a.studentIdNumber ?? '';
    _drivingLicenceCtrl.text = a.drivingLicenceNumber ?? '';
    _dob = a.dateOfBirth;

    // Detect if global
    if (a.countryCode != null && a.countryCode != 'BD') {
      _isGlobalMode = true;
      _countryNameCtrl.text = a.countryName ?? '';
      _stateNameCtrl.text = a.stateName ?? '';
      _cityNameCtrl.text = a.cityName ?? '';
      _addressLineCtrl.text = a.addressLine ?? '';
      _latitude = a.latitude;
      _longitude = a.longitude;
      _formattedAddress = a.formattedAddress;
    } else {
      _isGlobalMode = false;
      _divisionId = a.divisionId;
      _districtId = a.districtId;
      _addressMode = _recoverAddressMode(a.verificationDraftJson);
      _cityCorporationId = _asInt(
        a.verificationDraftJson?['bdCityCorporationId'],
      );
      _zoneId = _asInt(a.verificationDraftJson?['bdZoneId']);
      _wardId = _asInt(a.verificationDraftJson?['bdWardId']);
      _upazilaId = a.upazilaId;
      _unionId = a.unionId;
      _areaId = a.areaId;
      _cityCorporationName = a.verificationDraftJson?['cityCorporationName']
          ?.toString();
      _zoneName = a.verificationDraftJson?['zoneName']?.toString();
      _wardName = a.verificationDraftJson?['wardName']?.toString();
      final storedAreaDetails = a.area?.trim();
      _areaName = (storedAreaDetails?.isNotEmpty ?? false)
          ? storedAreaDetails
          : a.verificationDraftJson?['areaName']?.toString();
    }

    // Names might not be present; UI will still work without them.
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Historical bound only — wide enough to cover any living person, no
    // invented "must be at least N years old" business rule.
    final earliest = DateTime(now.year - 120, 1, 1);
    final initial = _dob ?? DateTime(now.year - 30, 1, 1);
    final picked = await showDatePicker(
      context: context,
      firstDate: earliest,
      lastDate: today,
      initialDate: initial.isAfter(today) ? today : initial,
      // Year picker first so an older birth year is a couple of taps away
      // instead of scrolling months on the calendar grid.
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.calendar,
      helpText: 'Select date of birth',
      cancelText: 'Cancel',
      confirmText: 'Confirm',
      fieldLabelText: 'Date of birth',
      fieldHintText: 'DD/MM/YYYY',
      errorFormatText: 'Enter a valid date',
      errorInvalidText: 'Enter a date within range',
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('en', 'GB'), // Renders DD/MM/YYYY input.
          child: child,
        );
      },
    );
    if (picked == null) return;
    setState(() => _dob = DateTime(picked.year, picked.month, picked.day));
  }

  /// Human-facing DD/MM/YYYY display — kept distinct from the YYYY-MM-DD
  /// wire format sent to the API ([_dobDateOnly]).
  String _dobDisplay(DateTime dob) {
    final d = dob.day.toString().padLeft(2, '0');
    final m = dob.month.toString().padLeft(2, '0');
    return '$d/$m/${dob.year}';
  }

  /// Canonical date-only wire value (YYYY-MM-DD). Deliberately does not use
  /// `toIso8601String()`/UTC conversion, which can shift the calendar day.
  String? _dobDateOnly(DateTime? dob) {
    if (dob == null) return null;
    final y = dob.year.toString().padLeft(4, '0');
    final m = dob.month.toString().padLeft(2, '0');
    final d = dob.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickLocationFromMap() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _latitude ?? 23.8103,
          initialLng: _longitude ?? 90.4125,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _formattedAddress =
            '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
      });
    }
  }

  Map<String, dynamic> _snapshotRecovery() {
    return <String, dynamic>{
      'step': _verificationStep,
      'accountType': _accountType,
      'presentAddress': _presentAddressCtrl.text,
      'permanentAddress': _permanentAddressCtrl.text,
      'occupation': _occupationCtrl.text,
      'nid': _nidCtrl.text,
      'birthReg': _birthRegCtrl.text,
      'studentId': _studentIdCtrl.text,
      'passport': _passportCtrl.text,
      'dob': _dob?.toIso8601String(),
      'divisionId': _divisionId,
      'districtId': _districtId,
      'bdAddressMode': _addressMode == null
          ? null
          : (_addressMode == LocationAddressMode.urban ? 'URBAN' : 'RURAL'),
      'bdCityCorporationId': _cityCorporationId,
      'bdZoneId': _zoneId,
      'bdWardId': _wardId,
      'upazilaId': _upazilaId,
      'unionId': _unionId,
      'divisionName': _divisionName,
      'districtName': _districtName,
      'cityCorporationName': _cityCorporationName,
      'zoneName': _zoneName,
      'wardName': _wardName,
      'upazilaName': _upazilaName,
      'unionName': _unionName,
      'areaName': _areaName,
      'isGlobalMode': _isGlobalMode,
      'countryName': _countryNameCtrl.text,
      'stateName': _stateNameCtrl.text,
      'cityName': _cityNameCtrl.text,
      'addressLine': _addressLineCtrl.text,
      'latitude': _latitude,
      'longitude': _longitude,
      'formattedAddress': _formattedAddress,
      'orgName': _orgNameCtrl.text,
      'orgDesc': _orgDescCtrl.text,
      'orgWorkType': _orgWorkTypeCtrl.text,
      'sameAsPresentAddress': _sameAsPresentAddress,
      'primaryDocumentType': _primaryDocumentType,
      'consentGiven': _consentGiven,
    };
  }

  void _applyRecovery(Map<String, dynamic> data) {
    _verificationStep = fundraisingInt(data['step']) ?? _verificationStep;
    _accountType = (data['accountType'] ?? _accountType).toString();
    _presentAddressCtrl.text =
        (data['presentAddress'] ?? _presentAddressCtrl.text).toString();
    _permanentAddressCtrl.text =
        (data['permanentAddress'] ?? _permanentAddressCtrl.text).toString();
    _occupationCtrl.text = (data['occupation'] ?? _occupationCtrl.text)
        .toString();
    _nidCtrl.text = (data['nid'] ?? _nidCtrl.text).toString();
    _birthRegCtrl.text = (data['birthReg'] ?? _birthRegCtrl.text).toString();
    _studentIdCtrl.text = (data['studentId'] ?? _studentIdCtrl.text).toString();
    _passportCtrl.text = (data['passport'] ?? _passportCtrl.text).toString();
    _dob = DateTime.tryParse((data['dob'] ?? '').toString()) ?? _dob;
    _divisionId = fundraisingInt(data['divisionId']) ?? _divisionId;
    _districtId = fundraisingInt(data['districtId']) ?? _districtId;
    _addressMode = _recoverAddressMode(data) ?? _addressMode;
    _cityCorporationId =
        fundraisingInt(data['bdCityCorporationId']) ??
        fundraisingInt(data['cityCorporationId']) ??
        _cityCorporationId;
    _zoneId =
        fundraisingInt(data['bdZoneId']) ??
        fundraisingInt(data['zoneId']) ??
        _zoneId;
    _wardId =
        fundraisingInt(data['bdWardId']) ??
        fundraisingInt(data['wardId']) ??
        _wardId;
    _upazilaId = fundraisingInt(data['upazilaId']) ?? _upazilaId;
    _unionId = fundraisingInt(data['unionId']) ?? _unionId;
    _divisionName = (data['divisionName'] ?? _divisionName)?.toString();
    _districtName = (data['districtName'] ?? _districtName)?.toString();
    _cityCorporationName = (data['cityCorporationName'] ?? _cityCorporationName)
        ?.toString();
    _zoneName = (data['zoneName'] ?? _zoneName)?.toString();
    _wardName = (data['wardName'] ?? _wardName)?.toString();
    _upazilaName = (data['upazilaName'] ?? _upazilaName)?.toString();
    _unionName = (data['unionName'] ?? _unionName)?.toString();
    _areaName = (data['areaName'] ?? _areaName)?.toString();
    _isGlobalMode = data['isGlobalMode'] == true;
    _countryNameCtrl.text = (data['countryName'] ?? _countryNameCtrl.text)
        .toString();
    _stateNameCtrl.text = (data['stateName'] ?? _stateNameCtrl.text).toString();
    _cityNameCtrl.text = (data['cityName'] ?? _cityNameCtrl.text).toString();
    _addressLineCtrl.text = (data['addressLine'] ?? _addressLineCtrl.text)
        .toString();
    _latitude = fundraisingDouble(data['latitude']) ?? _latitude;
    _longitude = fundraisingDouble(data['longitude']) ?? _longitude;
    _formattedAddress = (data['formattedAddress'] ?? _formattedAddress)
        ?.toString();
    _orgNameCtrl.text = (data['orgName'] ?? _orgNameCtrl.text).toString();
    _orgDescCtrl.text = (data['orgDesc'] ?? _orgDescCtrl.text).toString();
    _orgWorkTypeCtrl.text = (data['orgWorkType'] ?? _orgWorkTypeCtrl.text)
        .toString();
    _sameAsPresentAddress = data['sameAsPresentAddress'] == true;
    _primaryDocumentType = (data['primaryDocumentType'] ?? _primaryDocumentType)
        .toString();
    _consentGiven = data['consentGiven'] == true;
  }

  Future<void> _sanitizeRestoredBangladeshSelection() async {
    if (_isGlobalMode || _divisionId == null) return;
    final isUrban =
        _addressMode == LocationAddressMode.urban ||
        _cityCorporationId != null ||
        _zoneId != null ||
        _wardId != null;
    try {
      await ref
          .read(bdLocationsRepositoryProvider)
          .validateSelection(
            divisionId: _divisionId,
            districtId: _districtId,
            cityCorporationId: isUrban ? _cityCorporationId : null,
            zoneId: isUrban ? _zoneId : null,
            wardId: isUrban ? _wardId : null,
            upazilaId: isUrban ? null : _upazilaId,
            unionId: isUrban ? null : _unionId,
          );
    } on ApiClientException catch (error) {
      final code = (error.code ?? '').toUpperCase();
      const knownMismatchCodes = <String>{
        'DISTRICT_DIVISION_MISMATCH',
        'UPAZILA_DISTRICT_MISMATCH',
        'UNION_UPAZILA_MISMATCH',
        'LOCATION_ID_NOT_FOUND',
      };
      if (!knownMismatchCodes.contains(code)) {
        // Not a known "restored selection no longer valid" business error —
        // e.g. a network/server failure. Let the caller surface this as a
        // scoped, retryable location-section error instead of silently
        // swallowing it.
        rethrow;
      }
      if (!mounted) return;
      setState(() {
        if (isUrban) {
          if (code == 'DISTRICT_DIVISION_MISMATCH') {
            _districtId = null;
            _districtName = null;
          }
          if (code == 'LOCATION_ID_NOT_FOUND' ||
              code == 'DISTRICT_DIVISION_MISMATCH') {
            _addressMode = null;
            _cityCorporationId = null;
            _cityCorporationName = null;
            _zoneId = null;
            _zoneName = null;
            _wardId = null;
            _wardName = null;
            _areaName = null;
          } else if (code == 'UNION_UPAZILA_MISMATCH') {
            _unionId = null;
            _unionName = null;
            _areaName = null;
          }
          return;
        }
        if (code == 'DISTRICT_DIVISION_MISMATCH') {
          _districtId = null;
          _districtName = null;
          _upazilaId = null;
          _upazilaName = null;
          _unionId = null;
          _unionName = null;
          _areaName = null;
        } else if (code == 'UPAZILA_DISTRICT_MISMATCH') {
          _upazilaId = null;
          _upazilaName = null;
          _unionId = null;
          _unionName = null;
          _areaName = null;
        } else if (code == 'UNION_UPAZILA_MISMATCH' ||
            code == 'LOCATION_ID_NOT_FOUND') {
          _unionId = null;
          _unionName = null;
          _areaName = null;
        }
      });
    }
  }

  Future<void> _persistRecovery() async {
    await ref
        .read(fundraisingVerificationRecoveryServiceProvider)
        .save(_snapshotRecovery());
  }

  bool _hasPrimaryIdentityMethod() {
    final selected = _primaryDocumentType.toUpperCase();
    switch (selected) {
      case 'NID':
        return _nidCtrl.text.trim().isNotEmpty;
      case 'BIRTH REGISTRATION':
      case 'BIRTH_REGISTRATION':
      case 'BIRTHREG':
      case 'BIRTH':
        return _birthRegCtrl.text.trim().isNotEmpty;
      case 'PASSPORT':
        return _passportCtrl.text.trim().isNotEmpty;
      case 'SCHOOL/COLLEGE ID':
      case 'STUDENT ID':
      case 'STUDENT_ID':
        return _studentIdCtrl.text.trim().isNotEmpty;
      case 'DRIVING LICENCE':
      case 'DRIVING_LICENCE':
      case 'DRIVING':
        return _drivingLicenceCtrl.text.trim().isNotEmpty;
      default:
        return _nidCtrl.text.trim().isNotEmpty ||
            _birthRegCtrl.text.trim().isNotEmpty ||
            _passportCtrl.text.trim().isNotEmpty ||
            _studentIdCtrl.text.trim().isNotEmpty ||
            _drivingLicenceCtrl.text.trim().isNotEmpty;
    }
  }

  bool _hasPrimaryVerificationDocument() {
    final docs = _account?.documents ?? const <FundraisingAccountDocument>[];
    return docs.any((doc) => doc.isPrimary);
  }

  bool _validateCurrentStep(FundraisingAccountReadiness readiness) {
    switch (_verificationStep) {
      case 0:
        if (_isGlobalMode) {
          return _countryNameCtrl.text.trim().isNotEmpty &&
              _addressLineCtrl.text.trim().isNotEmpty &&
              _presentAddressCtrl.text.trim().isNotEmpty &&
              _permanentAddressCtrl.text.trim().isNotEmpty;
        }
        final isUrban =
            _addressMode == LocationAddressMode.urban ||
            _cityCorporationId != null ||
            _zoneId != null ||
            _wardId != null;
        if (isUrban) {
          return _divisionId != null &&
              _districtId != null &&
              _cityCorporationId != null &&
              _zoneId != null &&
              _wardId != null &&
              _presentAddressCtrl.text.trim().isNotEmpty &&
              _permanentAddressCtrl.text.trim().isNotEmpty;
        }
        return _divisionId != null &&
            _districtId != null &&
            _upazilaId != null &&
            _unionId != null &&
            _presentAddressCtrl.text.trim().isNotEmpty &&
            _permanentAddressCtrl.text.trim().isNotEmpty;
      case 1:
        return _fullNameCtrl.text.trim().isNotEmpty &&
            _dob != null &&
            _occupationCtrl.text.trim().isNotEmpty &&
            _hasPrimaryIdentityMethod();
      case 2:
        return _hasPrimaryVerificationDocument();
      case 3:
        return _consentGiven;
      case 4:
        return true;
      default:
        return true;
    }
  }

  Future<String?> _validateBangladeshSelectionOnSave() async {
    if (_isGlobalMode) return null;
    try {
      final isUrban =
          _addressMode == LocationAddressMode.urban ||
          _cityCorporationId != null ||
          _zoneId != null ||
          _wardId != null;
      await ref
          .read(bdLocationsRepositoryProvider)
          .validateSelection(
            divisionId: _divisionId,
            districtId: _districtId,
            cityCorporationId: isUrban ? _cityCorporationId : null,
            zoneId: isUrban ? _zoneId : null,
            wardId: isUrban ? _wardId : null,
            upazilaId: isUrban ? null : _upazilaId,
            unionId: isUrban ? null : _unionId,
          );
      return null;
    } on Object catch (error) {
      return mapFundraisingSafeError(error).message;
    }
  }

  Map<String, dynamic> _accountPayload() {
    final permanent = _sameAsPresentAddress
        ? _presentAddressCtrl.text.trim()
        : _permanentAddressCtrl.text.trim();
    final isUrban =
        _addressMode == LocationAddressMode.urban ||
        _cityCorporationId != null ||
        _zoneId != null ||
        _wardId != null;
    final areaSnapshot = _areaName?.trim();
    return <String, dynamic>{
      'accountType': _accountType,
      'fullName': _fullNameCtrl.text.trim(),
      'presentAddress': _presentAddressCtrl.text.trim(),
      'permanentAddress': permanent,
      'occupation': _occupationCtrl.text.trim(),
      'isInternational': _isGlobalMode,
      'divisionId': _isGlobalMode ? null : _divisionId,
      'districtId': _isGlobalMode ? null : _districtId,
      'upazilaId': _isGlobalMode || isUrban ? null : _upazilaId,
      'unionId': _isGlobalMode || isUrban ? null : _unionId,
      'bdAddressMode': _isGlobalMode ? null : (isUrban ? 'URBAN' : 'RURAL'),
      'bdCityCorporationId': _isGlobalMode || !isUrban
          ? null
          : _cityCorporationId,
      'bdZoneId': _isGlobalMode || !isUrban ? null : _zoneId,
      'bdWardId': _isGlobalMode || !isUrban ? null : _wardId,
      'bdUpazilaId': _isGlobalMode || isUrban ? null : _upazilaId,
      'bdUnionId': _isGlobalMode || isUrban ? null : _unionId,
      'area': _isGlobalMode ? null : areaSnapshot,
      'countryCode': _isGlobalMode ? 'GL' : 'BD',
      'countryName': _isGlobalMode ? _countryNameCtrl.text.trim() : null,
      'stateName': _isGlobalMode ? _stateNameCtrl.text.trim() : null,
      'cityName': _isGlobalMode ? _cityNameCtrl.text.trim() : null,
      'addressLine': _isGlobalMode ? _addressLineCtrl.text.trim() : null,
      'latitude': _isGlobalMode ? _latitude : null,
      'longitude': _isGlobalMode ? _longitude : null,
      'formattedAddress': _isGlobalMode ? _formattedAddress : null,
      'dateOfBirth': _dobDateOnly(_dob),
      'primaryDocumentType': _primaryDocumentType,
      'nationalIdNumber': _nidCtrl.text.trim().isEmpty
          ? null
          : _nidCtrl.text.trim(),
      'birthRegNumber': _birthRegCtrl.text.trim().isEmpty
          ? null
          : _birthRegCtrl.text.trim(),
      'studentIdNumber': _studentIdCtrl.text.trim().isEmpty
          ? null
          : _studentIdCtrl.text.trim(),
      'passportNumber': _passportCtrl.text.trim().isEmpty
          ? null
          : _passportCtrl.text.trim(),
      'drivingLicenceNumber': _drivingLicenceCtrl.text.trim().isEmpty
          ? null
          : _drivingLicenceCtrl.text.trim(),
      if (_accountType == 'ORGANIZATION') 'orgName': _orgNameCtrl.text.trim(),
      if (_accountType == 'ORGANIZATION')
        'orgDescription': _orgDescCtrl.text.trim(),
      if (_accountType == 'ORGANIZATION')
        'orgWorkType': _orgWorkTypeCtrl.text.trim(),
      'verificationDraftJson': _snapshotRecovery(),
    };
  }

  LocationAddressMode? _recoverAddressMode(Map<String, dynamic>? data) {
    final raw = data?['bdAddressMode']?.toString().trim().toUpperCase();
    switch (raw) {
      case 'URBAN':
        return LocationAddressMode.urban;
      case 'RURAL':
        return LocationAddressMode.rural;
      default:
        return null;
    }
  }

  int? _asInt(Object? value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  Future<void> _saveCurrentStep({
    bool advance = true,
    bool submit = false,
  }) async {
    if (_saving) return;
    final readiness =
        _account?.readiness ?? FundraisingAccountReadiness.fromAccount(null);
    final requireComplete = advance || submit;
    if (requireComplete && !_validateCurrentStep(readiness)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the current step first.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);
      final selectionError = await _validateBangladeshSelectionOnSave();
      if (selectionError != null) {
        throw FundraisingUserSafeException(selectionError);
      }
      if (_verificationStep == 0 ||
          _verificationStep == 1 ||
          _verificationStep == 3) {
        await repo.updateMyAccount(_accountPayload());
        await _persistRecovery();
        ref.invalidate(fundraisingMyAccountProvider);
        await _loadAccount(keepVisibleWhileLoading: true);
      }
      if (submit) {
        await repo.submitMyAccount();
        await _persistRecovery();
        ref.invalidate(fundraisingMyAccountProvider);
        await _loadAccount(keepVisibleWhileLoading: true);
      }
      if (advance && _verificationStep < 4) {
        setState(() => _verificationStep += 1);
      }
      _hasUnsavedChanges = false;
      final refreshed =
          _account?.readiness ?? FundraisingAccountReadiness.fromAccount(null);
      if (submit && refreshed.canStartFundraiser) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFundraisingSafeError(error).message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final readiness =
        _account?.readiness ?? FundraisingAccountReadiness.fromAccount(null);
    final submit =
        _verificationStep == 4 &&
        readiness.canStartFundraiser &&
        (readiness.status == 'DRAFT' ||
            readiness.status == 'REJECTED' ||
            readiness.status == 'UNKNOWN');
    await _saveCurrentStep(advance: _verificationStep < 4, submit: submit);
  }

  Future<bool> _confirmLeaveWizard() async {
    if (!_hasUnsavedChanges && !_saving && !_busyDoc) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Leave verification?'),
          content: const Text(
            'You have unsaved verification changes. Save before leaving?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    return leave ?? false;
  }

  Widget _buildVerificationWizard(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final readiness =
        _account?.readiness ?? FundraisingAccountReadiness.fromAccount(null);
    final currentUser = ref.watch(currentUserProvider);
    final stepTitle = _verificationStepTitle(t);
    final stepLabel = t.fundraisingWizardStepOf(_verificationStep + 1, 5);

    return WillPopScope(
      onWillPop: _confirmLeaveWizard,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmLeaveWizard() && context.mounted) {
                navigator.maybePop();
              }
            },
          ),
          title: Text(t.fundraisingVerificationWizardTitle),
        ),
        body: SafeArea(
          child: Column(
            children: [
              FundraisingStepHeader(
                stepLabel: stepLabel,
                title: stepTitle,
                progress: (_verificationStep + 1) / 5,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_verificationStep),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        184 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: _buildStepBody(context, readiness, currentUser),
                    ),
                  ),
                ),
              ),
              FundraisingWizardBottomBar(
                // Spinner reserved for the actual "Submit for review" action
                // on the final step — ordinary Continue/Save draft saves on
                // earlier steps stay disabled-but-static.
                busy: _saving && _verificationStep == 4,
                disabled: _saving || _busyDoc,
                canGoBack: _verificationStep > 0,
                onBack: () async {
                  if (_verificationStep == 0) {
                    if (await _confirmLeaveWizard() && context.mounted) {
                      Navigator.of(context).maybePop();
                    }
                    return;
                  }
                  setState(() => _verificationStep -= 1);
                },
                onContinue: () async {
                  final navigator = Navigator.of(context);
                  if (_verificationStep == 4 && readiness.canStartFundraiser) {
                    await _persistRecovery();
                    if (mounted) {
                      navigator.pop(true);
                    }
                    return;
                  }
                  final submit =
                      _verificationStep == 4 &&
                      readiness.canStartFundraiser &&
                      (readiness.status == 'DRAFT' ||
                          readiness.status == 'REJECTED' ||
                          readiness.status == 'UNKNOWN');
                  _saveCurrentStep(
                    advance: _verificationStep < 4,
                    submit: submit,
                  );
                },
                continueLabel: _continueLabel(t, readiness),
                onCancel: () async {
                  if (await _confirmLeaveWizard() && context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
                onSaveDraft: () => _saveCurrentStep(advance: false),
                showSaveDraft: _verificationStep < 4,
                continueEnabled:
                    !_saving &&
                    !_busyDoc &&
                    (_verificationStep < 4
                        ? _validateCurrentStep(readiness)
                        : readiness.canStartFundraiser),
                helperText: null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _verificationStepTitle(AppLocalizations t) {
    switch (_verificationStep) {
      case 0:
        return t.fundraisingVerificationStepAccountLocation;
      case 1:
        return t.fundraisingVerificationStepIdentityDetails;
      case 2:
        return t.fundraisingVerificationStepDocuments;
      case 3:
        return t.fundraisingVerificationStepReviewConsent;
      case 4:
      default:
        return t.fundraisingVerificationStepSubmissionStatus;
    }
  }

  String _continueLabel(
    AppLocalizations t,
    FundraisingAccountReadiness readiness,
  ) {
    if (_verificationStep == 4) {
      if (readiness.canStartFundraiser &&
          (readiness.status == 'PENDING' ||
              readiness.status == 'PENDING_REVIEW' ||
              readiness.status == 'VERIFIED')) {
        return t.fundraisingContinueToFundraiser;
      }
      return t.fundraisingSubmitForReview;
    }
    return t.continueLabel;
  }

  Widget _buildStepBody(
    BuildContext context,
    FundraisingAccountReadiness readiness,
    CurrentUser currentUser,
  ) {
    switch (_verificationStep) {
      case 0:
        return _buildStepOne(context, readiness);
      case 1:
        return _buildStepTwo(context);
      case 2:
        return _buildStepThree(context, readiness);
      case 3:
        return _buildStepFour(context, readiness);
      case 4:
      default:
        return _buildStepFive(context, readiness);
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildStepOne(
    BuildContext context,
    FundraisingAccountReadiness readiness,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBanner(readiness: readiness),
          const SizedBox(height: 16),
          _sectionTitle('Account type'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _accountType,
            decoration: const InputDecoration(
              labelText: 'Account type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'INDIVIDUAL', child: Text('Individual')),
              DropdownMenuItem(
                value: 'ORGANIZATION',
                child: Text('Organization'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _accountType = value ?? 'INDIVIDUAL';
                    _hasUnsavedChanges = true;
                  }),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Location and addresses'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Global / International location'),
            subtitle: const Text('Enable this if you are outside Bangladesh'),
            value: _isGlobalMode,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _isGlobalMode = value;
                    _hasUnsavedChanges = true;
                  }),
          ),
          const SizedBox(height: 8),
          if (!_isGlobalMode && _locationCatalogError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _locationCatalogError!.message,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: _locationCatalogRetrying
                        ? null
                        : _retryLocationCatalog,
                    child: _locationCatalogRetrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Retry'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (!_isGlobalMode)
            LocationSelectorWidget(
              divisionId: _divisionId,
              districtId: _districtId,
              addressMode: _addressMode,
              cityCorporationId: _cityCorporationId,
              zoneId: _zoneId,
              wardId: _wardId,
              upazilaId: _upazilaId,
              unionId: _unionId,
              divisionName: _divisionName,
              districtName: _districtName,
              cityCorporationName: _cityCorporationName,
              zoneName: _zoneName,
              wardName: _wardName,
              upazilaName: _upazilaName,
              unionName: _unionName,
              areaName: _areaName,
              disabled: _saving,
              required: true,
              onDivisionChanged: _saving
                  ? null
                  : (id, name) {
                      final previousDistrictId = _districtId;
                      final previousUpazilaId = _upazilaId;
                      setState(() {
                        _divisionId = id;
                        _divisionName = name;
                        _districtId = null;
                        _districtName = null;
                        _addressMode = null;
                        _cityCorporationId = null;
                        _cityCorporationName = null;
                        _zoneId = null;
                        _zoneName = null;
                        _wardId = null;
                        _wardName = null;
                        _upazilaId = null;
                        _upazilaName = null;
                        _unionId = null;
                        _unionName = null;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                      if (id != null) {
                        ref.invalidate(bdDistrictsProvider(id));
                      }
                      if (previousDistrictId != null) {
                        ref.invalidate(bdUpazilasProvider(previousDistrictId));
                      }
                      if (previousUpazilaId != null) {
                        ref.invalidate(bdUnionsProvider(previousUpazilaId));
                        ref.invalidate(bdAreasProvider(previousUpazilaId));
                      }
                    },
              onDistrictChanged: _saving
                  ? null
                  : (id, name) {
                      final previousUpazilaId = _upazilaId;
                      setState(() {
                        _districtId = id;
                        _districtName = name;
                        _addressMode = null;
                        _cityCorporationId = null;
                        _cityCorporationName = null;
                        _zoneId = null;
                        _zoneName = null;
                        _wardId = null;
                        _wardName = null;
                        _upazilaId = null;
                        _upazilaName = null;
                        _unionId = null;
                        _unionName = null;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                      if (id != null) {
                        ref.invalidate(bdUpazilasProvider(id));
                      }
                      if (previousUpazilaId != null) {
                        ref.invalidate(bdUnionsProvider(previousUpazilaId));
                        ref.invalidate(bdAreasProvider(previousUpazilaId));
                      }
                    },
              onAddressModeChanged: _saving
                  ? null
                  : (mode) {
                      setState(() {
                        _addressMode = mode;
                        _cityCorporationId = null;
                        _cityCorporationName = null;
                        _zoneId = null;
                        _zoneName = null;
                        _wardId = null;
                        _wardName = null;
                        _upazilaId = null;
                        _upazilaName = null;
                        _unionId = null;
                        _unionName = null;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                    },
              onCityCorporationChanged: _saving
                  ? null
                  : (id, name) {
                      setState(() {
                        _addressMode = LocationAddressMode.urban;
                        _cityCorporationId = id;
                        _cityCorporationName = name;
                        _zoneId = null;
                        _zoneName = null;
                        _wardId = null;
                        _wardName = null;
                        _upazilaId = null;
                        _upazilaName = null;
                        _unionId = null;
                        _unionName = null;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                      if (id != null) {
                        ref.invalidate(bdZonesProvider(id));
                      }
                    },
              onZoneChanged: _saving
                  ? null
                  : (id, name) {
                      setState(() {
                        _addressMode = LocationAddressMode.urban;
                        _zoneId = id;
                        _zoneName = name;
                        _wardId = null;
                        _wardName = null;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                      if (id != null) {
                        ref.invalidate(bdWardsProvider(id));
                      }
                    },
              onWardChanged: _saving
                  ? null
                  : (id, name) {
                      setState(() {
                        _addressMode = LocationAddressMode.urban;
                        _wardId = id;
                        _wardName = name;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                    },
              onUpazilaChanged: _saving
                  ? null
                  : (id, name) {
                      setState(() {
                        _addressMode = LocationAddressMode.rural;
                        _upazilaId = id;
                        _upazilaName = name;
                        _cityCorporationId = null;
                        _cityCorporationName = null;
                        _zoneId = null;
                        _zoneName = null;
                        _wardId = null;
                        _wardName = null;
                        _unionId = null;
                        _unionName = null;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                      if (id != null) {
                        ref.invalidate(bdUnionsProvider(id));
                        ref.invalidate(bdAreasProvider(id));
                      }
                    },
              onUnionChanged: _saving
                  ? null
                  : (id, name) {
                      setState(() {
                        _addressMode = LocationAddressMode.rural;
                        _unionId = id;
                        _unionName = name;
                        _cityCorporationId = null;
                        _cityCorporationName = null;
                        _zoneId = null;
                        _zoneName = null;
                        _wardId = null;
                        _wardName = null;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                    },
              onAreaChanged: _saving
                  ? null
                  : (_, name) {
                      final details = (name ?? '').trim();
                      setState(() {
                        _areaName = details.isEmpty ? null : details;
                        _hasUnsavedChanges = true;
                      });
                    },
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _pickLocationFromMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(_formattedAddress ?? 'Pick location on map'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _countryNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Country *',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _hasUnsavedChanges = true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stateNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'State / Region',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cityNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressLineCtrl,
              decoration: const InputDecoration(
                labelText: 'Postal code / address line',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _hasUnsavedChanges = true),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _presentAddressCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Current address (Present)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() {
              if (_sameAsPresentAddress) {
                _permanentAddressCtrl.text = value;
              }
              _hasUnsavedChanges = true;
            }),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Current address is required'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _sameAsPresentAddress,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _sameAsPresentAddress = value ?? false;
                          if (_sameAsPresentAddress) {
                            _permanentAddressCtrl.text =
                                _presentAddressCtrl.text;
                          }
                          _hasUnsavedChanges = true;
                        });
                      },
              ),
              const Expanded(child: Text('Same as present address')),
            ],
          ),
          TextFormField(
            controller: _permanentAddressCtrl,
            maxLines: 3,
            readOnly: _sameAsPresentAddress,
            decoration: const InputDecoration(
              labelText: 'Permanent address',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _hasUnsavedChanges = true),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Permanent address is required'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Identity details'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fullNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Full name',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _hasUnsavedChanges = true),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Full name is required' : null,
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Date of birth',
          value: _dob == null ? 'Not set' : _dobDisplay(_dob!),
          hint: 'Opens the date picker',
          child: InkWell(
            key: const ValueKey('fundraising-dob-field'),
            onTap: _saving ? null : _pickDob,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                hintText: 'DD/MM/YYYY',
                border: OutlineInputBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_dob == null ? 'Select date' : _dobDisplay(_dob!)),
                  const Icon(Icons.calendar_month),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _occupationCtrl,
          decoration: const InputDecoration(
            labelText: 'Occupation',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _hasUnsavedChanges = true),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Occupation is required' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _primaryDocumentType,
          decoration: const InputDecoration(
            labelText: 'Primary identity document',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'NID', child: Text('National ID')),
            DropdownMenuItem(
              value: 'BIRTH REGISTRATION',
              child: Text('Birth Registration'),
            ),
            DropdownMenuItem(value: 'PASSPORT', child: Text('Passport')),
            DropdownMenuItem(
              value: 'DRIVING LICENCE',
              child: Text('Driving Licence'),
            ),
            DropdownMenuItem(
              value: 'SCHOOL/COLLEGE ID',
              child: Text('School/College ID'),
            ),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() {
                  _primaryDocumentType = value ?? 'NID';
                  _hasUnsavedChanges = true;
                }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nidCtrl,
          decoration: const InputDecoration(
            labelText: 'National ID number',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _hasUnsavedChanges = true),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _birthRegCtrl,
          decoration: const InputDecoration(
            labelText: 'Birth registration number',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _hasUnsavedChanges = true),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passportCtrl,
          decoration: const InputDecoration(
            labelText: 'Passport number',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _hasUnsavedChanges = true),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _studentIdCtrl,
          decoration: const InputDecoration(
            labelText: 'School / college ID number',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _hasUnsavedChanges = true),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _drivingLicenceCtrl,
          decoration: const InputDecoration(
            labelText: 'Driving licence number',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _hasUnsavedChanges = true),
        ),
      ],
    );
  }

  List<FundraisingAccountDocument> _docsMatching(String query) {
    final docs = _account?.documents ?? const <FundraisingAccountDocument>[];
    final q = query.toLowerCase();
    return docs.where((doc) {
      final title = doc.title.toLowerCase();
      return title.contains(q) || doc.safeFileName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _replaceDocument(
    FundraisingAccountDocument document,
    String title, {
    required bool isPrimary,
  }) async {
    await _uploadRequiredDoc(
      title,
      replaceDocument: document,
      isPrimary: isPrimary,
    );
  }

  Future<void> _removeDocument(
    FundraisingAccountDocument document,
    String slotTitle,
  ) async {
    if (_busyDocSlots.contains(slotTitle)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document?'),
        content: const Text(
          'This document will be removed from your verification profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _busyDocSlots.add(slotTitle);
      _docSlotAction[slotTitle] = 'remove';
      _docSlotErrors.remove(slotTitle);
    });
    try {
      await ref.read(fundraisingRepositoryProvider).deleteDocument(document.id);
      ref.invalidate(fundraisingMyAccountProvider);
      await _loadAccount(keepVisibleWhileLoading: true);
      await _persistRecovery();
    } catch (error) {
      if (!mounted) return;
      final message = mapFundraisingSafeError(error).message;
      setState(() => _docSlotErrors[slotTitle] = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _busyDocSlots.remove(slotTitle);
          _docSlotAction.remove(slotTitle);
        });
      }
    }
  }

  Future<void> _previewVerificationDocument(
    FundraisingAccountDocument document,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FundraisingDocumentPreviewScreen(document: document),
      ),
    );
  }

  /// Human-facing upload timestamp (e.g. "Jul 29, 2026"), never a raw
  /// database timestamp with milliseconds.
  String _formatUploadedAt(DateTime dt) =>
      DateFormat.yMMMd().format(dt.toLocal());

  Widget _buildDocumentCard(
    String title,
    String subtitle,
    List<FundraisingAccountDocument> docs, {
    required bool requiredDocument,
  }) {
    final t = AppLocalizations.of(context)!;
    final document = docs.isNotEmpty ? docs.first : null;
    // Independent per-slot state — only this document card's buttons
    // disable while its own upload/replace/remove is in flight, and each
    // slot tracks its own Uploading/Replacing/Removing/Failed state.
    final slotBusy = _busyDocSlots.contains(title);
    final slotAction = _docSlotAction[title];
    final slotError = _docSlotErrors[title];
    final statusLabel = slotError != null
        ? 'Failed'
        : document == null
        ? (requiredDocument ? t.fundraisingRequired : t.fundraisingOptional)
        : t.fundraisingUploaded;
    final statusVariant = slotError != null
        ? FundraisingChipVariant.warning
        : document == null
        ? (requiredDocument
              ? FundraisingChipVariant.warning
              : FundraisingChipVariant.neutral)
        : FundraisingChipVariant.success;
    final busyLabel = switch (slotAction) {
      'replace' => 'Replacing...',
      'remove' => 'Removing...',
      _ => 'Uploading...',
    };

    final actions = <Widget>[
      if (document != null)
        TextButton(
          onPressed: () => _previewVerificationDocument(document),
          child: const Text('View'),
        ),
      TextButton(
        key: ValueKey(
          'doc-action-${document == null ? 'upload' : 'replace'}-$title',
        ),
        onPressed: slotBusy
            ? null
            : () => document == null
                  ? _uploadRequiredDoc(title, isPrimary: requiredDocument)
                  : _replaceDocument(
                      document,
                      title,
                      isPrimary: requiredDocument,
                    ),
        child: (slotBusy && slotAction != 'remove')
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                slotError != null
                    ? 'Retry'
                    : (document == null ? 'Upload' : 'Replace'),
              ),
      ),
      if (document != null)
        TextButton(
          key: ValueKey('doc-action-remove-$title'),
          onPressed: slotBusy ? null : () => _removeDocument(document, title),
          child: (slotBusy && slotAction == 'remove')
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Remove'),
        ),
    ];

    return FundraisingSectionCard(
      title: title,
      subtitle: subtitle,
      trailing: FundraisingStatusChip(
        label: slotBusy ? busyLabel : statusLabel,
        variant: statusVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (document != null) ...[
            FundraisingInlineMessage(
              variant: FundraisingInlineMessageVariant.success,
              message: document.safeFileName,
              icon: Icons.attachment_outlined,
            ),
            if (document.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Uploaded ${_formatUploadedAt(document.createdAt!)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
          ],
          if (slotError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FundraisingInlineMessage(
                variant: FundraisingInlineMessageVariant.danger,
                message: slotError,
                icon: Icons.error_outline,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Private and only visible to reviewers during verification.',
            style: context.appText.bodySmall!.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  Widget _buildStepThree(
    BuildContext context,
    FundraisingAccountReadiness readiness,
  ) {
    final docs = _account?.documents ?? const <FundraisingAccountDocument>[];
    final primaryDocs = _docsMatching('verification');
    final selfieDocs = _docsMatching('selfie');
    final schoolDocs = _docsMatching('school');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verification documents',
          style: context.appText.bodyLarge!.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          'Primary verification document',
          'Upload a National ID, birth registration, passport, or another supported identity document.',
          primaryDocs.isNotEmpty ? primaryDocs : docs.take(1).toList(),
          requiredDocument: true,
        ),
        _buildDocumentCard(
          'Selfie / profile photo',
          'Optional supporting photo for faster review.',
          selfieDocs,
          requiredDocument: false,
        ),
        _buildDocumentCard(
          'School / college ID',
          'Optional supporting document, if available.',
          schoolDocs,
          requiredDocument: false,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busyDoc
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FundraisingAccountDocumentsScreen(),
                  ),
                ),
          child: const Text('Manage all documents'),
        ),
        if (!readiness.requiredDocumentsUploaded) ...[
          const SizedBox(height: 8),
          const FundraisingInlineMessage(
            variant: FundraisingInlineMessageVariant.warning,
            message:
                'Upload at least one primary verification document to continue.',
          ),
        ],
      ],
    );
  }

  Widget _buildStepFour(
    BuildContext context,
    FundraisingAccountReadiness readiness,
  ) {
    final docs = _account?.documents ?? const <FundraisingAccountDocument>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Review & consent'),
        const SizedBox(height: 8),
        _SummaryCard(
          title: 'Profile',
          body:
              'Full name: ${_fullNameCtrl.text.trim().isEmpty ? 'Not set' : _fullNameCtrl.text.trim()}\n'
              'Occupation: ${_occupationCtrl.text.trim()}\n'
              'Date of birth: ${_dob == null ? 'Not set' : _dobDisplay(_dob!)}',
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          title: 'Identity numbers',
          body:
              'NID: ${_maskSensitive(_nidCtrl.text)}\nBirth registration: ${_maskSensitive(_birthRegCtrl.text)}\nPassport: ${_maskSensitive(_passportCtrl.text)}\nSchool/College ID: ${_maskSensitive(_studentIdCtrl.text)}',
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          title: 'Documents',
          body: docs.isEmpty
              ? 'No documents uploaded yet.'
              : docs
                    .map((doc) => '${doc.title} • ${doc.safeFileName}')
                    .join('\n'),
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consentGiven,
          onChanged: _saving
              ? null
              : (value) => setState(() {
                  _consentGiven = value ?? false;
                  _hasUnsavedChanges = true;
                }),
          title: const Text('I confirm this information is accurate.'),
        ),
        const SizedBox(height: 4),
        const Text(
          'You must confirm the declaration before submitting for review.',
        ),
      ],
    );
  }

  Widget _buildStepFive(
    BuildContext context,
    FundraisingAccountReadiness readiness,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Submission & status'),
        const SizedBox(height: 8),
        _StatusBanner(readiness: readiness),
        const SizedBox(height: 12),
        _VerificationSummary(
          readiness: readiness,
          onNavigateToStep: (step) => setState(() => _verificationStep = step),
        ),
        const SizedBox(height: 12),
        if (readiness.isRejected && readiness.safeRejectionReason != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(readiness.safeRejectionReason!),
          ),
        const SizedBox(height: 12),
        Text(
          readiness.canStartFundraiser
              ? 'Your verification is complete enough to continue creating fundraisers while review is pending.'
              : 'Complete the missing items before you can continue.',
        ),
      ],
    );
  }

  String _maskSensitive(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Not provided';
    if (text.length <= 4) return '****';
    return '****${text.substring(text.length - 4)}';
  }

  Future<void> _uploadRequiredDoc(
    String title, {
    FundraisingAccountDocument? replaceDocument,
    bool isPrimary = false,
  }) async {
    // Dedupe duplicate taps for this slot, but never blocks other slots and
    // always clears in `finally` so the UI can't get stuck disabled.
    if (_busyDocSlots.contains(title)) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _busyDocSlots.add(title);
      _docSlotAction[title] = replaceDocument == null ? 'upload' : 'replace';
      _docSlotErrors.remove(title);
    });
    try {
      final mediaId = await _postsDs.uploadMedia(File(path));
      final repo = ref.read(fundraisingRepositoryProvider);
      await repo.addDocument(
        title: title,
        mediaId: mediaId,
        documentType: isPrimary ? 'PRIMARY' : 'SUPPORTING',
      );
      if (replaceDocument != null) {
        await repo.deleteDocument(replaceDocument.id);
      }
      ref.invalidate(fundraisingMyAccountProvider);
      await _loadAccount(keepVisibleWhileLoading: true);
      await _persistRecovery();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title uploaded')));
    } catch (e) {
      if (!mounted) return;
      final message = mapFundraisingSafeError(e).message;
      setState(() => _docSlotErrors[title] = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _busyDocSlots.remove(title);
          _docSlotAction.remove(title);
        });
      }
    }
  }

  String _errorTitleFor(FundraisingSafeError safeError, [Object? error]) {
    if (error is FundraisingAccountParseException) {
      return "We couldn't read the server response";
    }
    // Same code-first mapping the Create Fundraiser preflight uses, so a
    // recognized domain error (409/403/503/500) never collapses into a
    // generic "Verification unavailable".
    return fundraisingErrorTitle(safeError);
  }

  @override
  Widget build(BuildContext context) {
    switch (_screenState) {
      case _VerificationScreenState.loadingAccount:
        return const Scaffold(
          body: FundraisingLoadingView(
            message: 'Preparing your verification...',
          ),
        );
      case _VerificationScreenState.accountLoadError:
        final safeError =
            _loadError ??
            const FundraisingSafeError(
              category: FundraisingErrorCategory.unknown,
              message: 'Something went wrong. Please try again.',
            );
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const Text('Fundraising verification'),
          ),
          body: FundraisingErrorView(
            title: _errorTitleFor(safeError),
            message: safeError.message,
            onRetry: () async {
              // _loadAccount() itself is deduplicated via
              // _accountLoadInFlight, and FundraisingErrorView guards
              // against re-entrant taps — together this makes repeated
              // Retry taps issue a single request.
              ref.invalidate(fundraisingMyAccountProvider);
              await _loadAccount(keepVisibleWhileLoading: true);
            },
          ),
        );
      case _VerificationScreenState.firstTimeSetup:
      case _VerificationScreenState.editingExisting:
        return _buildVerificationWizard(context);
    }
    // ignore: dead_code
    final myAcc = ref.watch(fundraisingMyAccountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Fundraising verification'),
      ),
      body: myAcc.when(
        loading: () => const FundraisingLoadingView(),
        error: (e, _) {
          final safeError = mapFundraisingSafeError(e);
          return FundraisingErrorView(
            title: _errorTitleFor(safeError, e),
            message: safeError.message,
            onRetry: () async {
              ref.invalidate(fundraisingMyAccountProvider);
              await ref.read(fundraisingMyAccountProvider.future);
            },
          );
        },
        data: (acc) {
          _prefill(acc ?? widget.initialAccount);

          final account = acc ?? widget.initialAccount;
          final readiness =
              widget.initialReadiness ??
              account?.readiness ??
              FundraisingAccountReadiness.fromAccount(null);
          final docs =
              account?.documents ?? const <FundraisingAccountDocument>[];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Verification status summary',
                      style: context.appText.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusBanner(readiness: readiness),
                    if (readiness.missingProfileFields.isNotEmpty ||
                        readiness.missingDocumentTypes.isNotEmpty ||
                        readiness.isRejected ||
                        readiness.isPendingReview) ...[
                      const SizedBox(height: 12),
                      _VerificationSummary(
                        readiness: readiness,
                        onNavigateToStep: (_) {},
                      ),
                    ],
                    const SizedBox(height: 14),

                    Text(
                      'Account type',
                      style: context.appText.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _accountType,
                      decoration: const InputDecoration(
                        labelText: 'Account type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'INDIVIDUAL',
                          child: Text('Individual'),
                        ),
                        DropdownMenuItem(
                          value: 'ORGANIZATION',
                          child: Text('Organization'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              setState(() => _accountType = v ?? 'INDIVIDUAL');
                            },
                    ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 16),
                    Text(
                      'Location and addresses',
                      style: context.appText.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Global / International Location'),
                      subtitle: const Text(
                        'Enable this if you are outside Bangladesh',
                      ),
                      value: _isGlobalMode,
                      onChanged: (val) {
                        setState(() => _isGlobalMode = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Location dropdowns or Global Fields
                    if (!_isGlobalMode) ...[
                      // Location dropdowns
                      LocationSelectorWidget(
                        divisionId: _divisionId,
                        districtId: _districtId,
                        upazilaId: _upazilaId,
                        unionId: _unionId,
                        divisionName: _divisionName,
                        districtName: _districtName,
                        upazilaName: _upazilaName,
                        unionName: _unionName,
                        areaName: _areaName,
                        disabled: _saving,
                        required: true,
                        onDivisionChanged: _saving
                            ? null
                            : (id, name) {
                                final previousDistrictId = _districtId;
                                final previousUpazilaId = _upazilaId;
                                setState(() {
                                  _divisionId = id;
                                  _divisionName = name;
                                  _districtId = null;
                                  _districtName = null;
                                  _upazilaId = null;
                                  _upazilaName = null;
                                  _unionId = null;
                                  _unionName = null;
                                  _areaId = null;
                                  _areaName = null;
                                });
                                if (id != null) {
                                  ref.invalidate(bdDistrictsProvider(id));
                                }
                                if (previousDistrictId != null) {
                                  ref.invalidate(
                                    bdUpazilasProvider(previousDistrictId),
                                  );
                                }
                                if (previousUpazilaId != null) {
                                  ref.invalidate(
                                    bdUnionsProvider(previousUpazilaId),
                                  );
                                  ref.invalidate(
                                    bdAreasProvider(previousUpazilaId),
                                  );
                                }
                              },
                        onDistrictChanged: _saving
                            ? null
                            : (id, name) {
                                final previousUpazilaId = _upazilaId;
                                setState(() {
                                  _districtId = id;
                                  _districtName = name;
                                  _upazilaId = null;
                                  _upazilaName = null;
                                  _unionId = null;
                                  _unionName = null;
                                  _areaId = null;
                                  _areaName = null;
                                });
                                if (id != null) {
                                  ref.invalidate(bdUpazilasProvider(id));
                                }
                                if (previousUpazilaId != null) {
                                  ref.invalidate(
                                    bdUnionsProvider(previousUpazilaId),
                                  );
                                  ref.invalidate(
                                    bdAreasProvider(previousUpazilaId),
                                  );
                                }
                              },
                        onUpazilaChanged: _saving
                            ? null
                            : (id, name) {
                                setState(() {
                                  _upazilaId = id;
                                  _upazilaName = name;
                                  _unionId = null;
                                  _unionName = null;
                                  _areaId = null;
                                  _areaName = null;
                                });
                                if (id != null) {
                                  ref.invalidate(bdUnionsProvider(id));
                                  ref.invalidate(bdAreasProvider(id));
                                }
                              },
                        onUnionChanged: _saving
                            ? null
                            : (id, name) {
                                setState(() {
                                  _unionId = id;
                                  _unionName = name;
                                  _areaId = null;
                                  _areaName = null;
                                });
                              },
                        onAreaChanged: _saving
                            ? null
                            : (_, name) {
                                final details = (name ?? '').trim();
                                setState(() {
                                  _areaName = details.isEmpty ? null : details;
                                  _unionId = null;
                                  _unionName = null;
                                });
                              },
                      ),
                    ] else ...[
                      // Global Fields
                      OutlinedButton.icon(
                        onPressed: _pickLocationFromMap,
                        icon: const Icon(Icons.map),
                        label: Text(
                          _formattedAddress ?? 'Pick Location on Map',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _countryNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Country *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stateNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'State / Province',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cityNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressLineCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Address Line / Street',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    const SizedBox(height: 16),
                    Text(
                      'Identity details',
                      style: context.appText.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _presentAddressCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Current address (Present)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Current address is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _permanentAddressCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Permanent address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Permanent address is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // DOB
                    InkWell(
                      onTap: _saving ? null : _pickDob,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of birth',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _dob == null
                                  ? 'Select date'
                                  : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                            ),
                            const Icon(Icons.calendar_month),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _occupationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Occupation',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Occupation is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // ID numbers
                    TextFormField(
                      controller: _nidCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'National ID number (optional if you provide other ID)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _birthRegCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Birth registration number (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _studentIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'School/College ID number (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_accountType == 'ORGANIZATION') ...[
                      Text(
                        'Organization info',
                        style: context.appText.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _orgNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Organization name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Organization name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _orgDescCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Organization description',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Organization description is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _orgWorkTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Work type',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Work type is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 16),
                    Text(
                      'Required documents',
                      style: context.appText.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DocTile(
                      title: 'Verification document',
                      subtitle:
                          'Upload one accepted identity document such as NID, birth registration, or passport.',
                      busy: _busyDoc,
                      onUpload: () =>
                          _uploadRequiredDoc('Verification document'),
                    ),
                    const SizedBox(height: 8),
                    _DocTile(
                      title: 'Selfie / profile photo',
                      subtitle: 'Optional supporting photo for faster review.',
                      busy: _busyDoc,
                      onUpload: () => _uploadRequiredDoc('Selfie photo'),
                    ),
                    const SizedBox(height: 8),
                    _DocTile(
                      title: 'School / college ID',
                      subtitle: 'Optional supporting document, if available.',
                      busy: _busyDoc,
                      onUpload: () => _uploadRequiredDoc('Student ID'),
                    ),
                    const SizedBox(height: 10),

                    if (docs.isNotEmpty) ...[
                      Text(
                        'Uploaded (${docs.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...docs
                          .take(6)
                          .map(
                            (d) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.attachment),
                              title: Text(d.title),
                              subtitle: Text(d.safeFileName),
                            ),
                          ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const FundraisingAccountDocumentsScreen(),
                          ),
                        ),
                        child: const Text('Manage all documents'),
                      ),
                    ] else ...[
                      const Text(
                        'No documents uploaded yet. Upload your verification document to continue.',
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const FundraisingAccountDocumentsScreen(),
                          ),
                        ),
                        child: const Text('Manage all documents'),
                      ),
                    ],

                    const SizedBox(height: 18),

                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        readiness.canStartFundraiser
                            ? 'Continue to fundraiser'
                            : 'Save verification info',
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'Save your verification details to keep them on file. You can continue to fundraiser once the required items are complete.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationForm(BuildContext context) {
    final account = _account;
    final readiness =
        account?.readiness ?? FundraisingAccountReadiness.fromAccount(null);
    final docs = account?.documents ?? const <FundraisingAccountDocument>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Fundraising verification'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verification status summary',
                  style: context.appText.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusBanner(readiness: readiness),
                if (readiness.missingProfileFields.isNotEmpty ||
                    readiness.missingDocumentTypes.isNotEmpty ||
                    readiness.isRejected ||
                    readiness.isPendingReview) ...[
                  const SizedBox(height: 12),
                  _VerificationSummary(
                    readiness: readiness,
                    onNavigateToStep: (_) {},
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Account type',
                  style: context.appText.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _accountType,
                  decoration: const InputDecoration(
                    labelText: 'Account type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'INDIVIDUAL',
                      child: Text('Individual'),
                    ),
                    DropdownMenuItem(
                      value: 'ORGANIZATION',
                      child: Text('Organization'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _accountType = v ?? 'INDIVIDUAL'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Location and addresses',
                  style: context.appText.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Global / International Location'),
                  subtitle: const Text(
                    'Enable this if you are outside Bangladesh',
                  ),
                  value: _isGlobalMode,
                  onChanged: _saving
                      ? null
                      : (val) => setState(() => _isGlobalMode = val),
                ),
                const SizedBox(height: 12),
                if (!_isGlobalMode)
                  LocationSelectorWidget(
                    divisionId: _divisionId,
                    districtId: _districtId,
                    upazilaId: _upazilaId,
                    unionId: _unionId,
                    divisionName: _divisionName,
                    districtName: _districtName,
                    upazilaName: _upazilaName,
                    unionName: _unionName,
                    areaName: _areaName,
                    disabled: _saving,
                    required: true,
                    onDivisionChanged: _saving
                        ? null
                        : (id, name) {
                            final previousDistrictId = _districtId;
                            final previousUpazilaId = _upazilaId;
                            setState(() {
                              _divisionId = id;
                              _divisionName = name;
                              _districtId = null;
                              _districtName = null;
                              _upazilaId = null;
                              _upazilaName = null;
                              _unionId = null;
                              _unionName = null;
                              _areaId = null;
                              _areaName = null;
                            });
                            if (id != null) {
                              ref.invalidate(bdDistrictsProvider(id));
                            }
                            if (previousDistrictId != null) {
                              ref.invalidate(
                                bdUpazilasProvider(previousDistrictId),
                              );
                            }
                            if (previousUpazilaId != null) {
                              ref.invalidate(
                                bdUnionsProvider(previousUpazilaId),
                              );
                              ref.invalidate(
                                bdAreasProvider(previousUpazilaId),
                              );
                            }
                          },
                    onDistrictChanged: _saving
                        ? null
                        : (id, name) {
                            final previousUpazilaId = _upazilaId;
                            setState(() {
                              _districtId = id;
                              _districtName = name;
                              _upazilaId = null;
                              _upazilaName = null;
                              _unionId = null;
                              _unionName = null;
                              _areaId = null;
                              _areaName = null;
                            });
                            if (id != null) {
                              ref.invalidate(bdUpazilasProvider(id));
                            }
                            if (previousUpazilaId != null) {
                              ref.invalidate(
                                bdUnionsProvider(previousUpazilaId),
                              );
                              ref.invalidate(
                                bdAreasProvider(previousUpazilaId),
                              );
                            }
                          },
                    onUpazilaChanged: _saving
                        ? null
                        : (id, name) {
                            setState(() {
                              _upazilaId = id;
                              _upazilaName = name;
                              _unionId = null;
                              _unionName = null;
                              _areaId = null;
                              _areaName = null;
                            });
                            if (id != null) {
                              ref.invalidate(bdUnionsProvider(id));
                              ref.invalidate(bdAreasProvider(id));
                            }
                          },
                    onUnionChanged: _saving
                        ? null
                        : (id, name) {
                            setState(() {
                              _unionId = id;
                              _unionName = name;
                              _areaId = null;
                              _areaName = null;
                            });
                          },
                    onAreaChanged: _saving
                        ? null
                        : (_, name) {
                            final details = (name ?? '').trim();
                            setState(() {
                              _areaName = details.isEmpty ? null : details;
                              _unionId = null;
                              _unionName = null;
                            });
                          },
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _pickLocationFromMap,
                    icon: const Icon(Icons.map),
                    label: Text(_formattedAddress ?? 'Pick Location on Map'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _countryNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Country *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stateNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'State / Province',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cityNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressLineCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address Line / Street',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Identity details',
                  style: context.appText.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _presentAddressCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Current address (Present)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Current address is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _permanentAddressCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Permanent address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Permanent address is required'
                      : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _saving ? null : _pickDob,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dob == null
                              ? 'Select date'
                              : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                        ),
                        const Icon(Icons.calendar_month),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _occupationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Occupation',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Occupation is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nidCtrl,
                  decoration: const InputDecoration(
                    labelText:
                        'National ID number (optional if you provide other ID)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthRegCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Birth registration number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'School/College ID number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_accountType == 'ORGANIZATION') ...[
                  Text(
                    'Organization info',
                    style: context.appText.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _orgNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Organization name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Organization name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orgDescCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Organization description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Organization description is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orgWorkTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Work type',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Work type is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                Text(
                  'Required documents',
                  style: context.appText.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _DocTile(
                  title: 'Verification document',
                  subtitle:
                      'Upload one accepted identity document such as NID, birth registration, or passport.',
                  busy: _busyDoc,
                  onUpload: () => _uploadRequiredDoc('Verification document'),
                ),
                const SizedBox(height: 8),
                _DocTile(
                  title: 'Selfie / profile photo',
                  subtitle: 'Optional supporting photo for faster review.',
                  busy: _busyDoc,
                  onUpload: () => _uploadRequiredDoc('Selfie photo'),
                ),
                const SizedBox(height: 8),
                _DocTile(
                  title: 'School / college ID',
                  subtitle: 'Optional supporting document, if available.',
                  busy: _busyDoc,
                  onUpload: () => _uploadRequiredDoc('Student ID'),
                ),
                const SizedBox(height: 10),
                if (docs.isNotEmpty) ...[
                  Text(
                    'Uploaded (${docs.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...docs
                      .take(6)
                      .map(
                        (d) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.attachment),
                          title: Text(d.title),
                          subtitle: Text(d.mediaUrl ?? ''),
                        ),
                      ),
                ] else ...[
                  const Text(
                    'No documents uploaded yet. Upload your verification document to continue.',
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FundraisingAccountDocumentsScreen(),
                    ),
                  ),
                  child: const Text('Manage all documents'),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    readiness.canStartFundraiser
                        ? 'Continue to fundraiser'
                        : 'Save verification info',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Save your verification details to keep them on file. You can continue to fundraiser once the required items are complete.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final FundraisingAccountReadiness readiness;
  const _StatusBanner({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final status = readiness.status.toUpperCase();
    final canStart = readiness.canStartFundraiser;
    String text;
    String hint;
    IconData icon;
    Color accent;

    // Six visually distinct states: Incomplete, Ready for review, Submitted
    // (under review), Approved, Rejected, and Restricted.
    switch (status) {
      case 'VERIFIED':
        text = t.fundraisingEligibilityVerified;
        hint = t.fundraisingEligibilitySummaryVerified;
        icon = Icons.verified;
        accent = Colors.green.shade700;
        break;
      case 'REJECTED':
        text = t.fundraisingEligibilityRejected;
        hint = t.fundraisingEligibilitySummaryRejected;
        icon = Icons.error_outline;
        accent = Colors.red.shade700;
        break;
      case 'SUSPENDED':
      case 'BLOCKED':
        text = t.fundraisingEligibilityRestricted;
        hint = t.fundraisingEligibilitySummaryRestricted;
        icon = Icons.block;
        accent = Colors.red.shade700;
        break;
      case 'PENDING':
      case 'PENDING_REVIEW':
        if (canStart) {
          text = 'Under review';
          hint = t.fundraisingEligibilitySummaryPending;
          icon = Icons.hourglass_top;
          accent = Colors.blue.shade700;
        } else {
          text = t.fundraisingEligibilityDraft;
          hint = t.fundraisingEligibilitySummaryActionRequired;
          icon = Icons.warning_amber_rounded;
          accent = Colors.orange.shade800;
        }
        break;
      default:
        if (canStart) {
          text = 'Ready for review';
          hint =
              'All required items are complete. Submit for review to get verified.';
          icon = Icons.task_alt;
          accent = Colors.blue.shade700;
        } else {
          text = t.fundraisingEligibilityDraft;
          hint = t.fundraisingEligibilitySummaryActionRequired;
          icon = Icons.warning_amber_rounded;
          accent = Colors.orange.shade800;
        }
        break;
    }

    return Semantics(
      label: '$text. $hint',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(hint, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationSummary extends StatelessWidget {
  const _VerificationSummary({
    required this.readiness,
    required this.onNavigateToStep,
  });

  final FundraisingAccountReadiness readiness;
  final ValueChanged<int> onNavigateToStep;

  @override
  Widget build(BuildContext context) {
    final missingRows = <_MissingItem>[
      ...readiness.missingProfileFields.map(_missingItemForField),
      ...readiness.missingDocumentTypes.map(_missingItemForDocument),
    ];

    if (missingRows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'All required verification items are complete.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        border: Border.all(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Text(
              'What still needs attention',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final item in missingRows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.error_outline,
                  color: Colors.orange.shade800,
                ),
                title: Text(item.label),
                trailing: TextButton(
                  key: ValueKey('fix-missing-${item.stepIndex}-${item.label}'),
                  onPressed: () => onNavigateToStep(item.stepIndex),
                  child: const Text('Fix'),
                ),
              ),
            ),
          if (readiness.isRejected &&
              readiness.safeRejectionReason != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(readiness.safeRejectionReason!),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  static _MissingItem _missingItemForField(String field) {
    switch (field) {
      case 'fullName':
        return const _MissingItem('Full name', 1);
      case 'dateOfBirth':
        return const _MissingItem('Date of birth', 1);
      case 'primaryDocumentType':
        return const _MissingItem('Primary identity document type', 1);
      case 'primaryDocumentNumber':
        return const _MissingItem(
          'Identity document number for the selected type',
          1,
        );
      case 'presentAddress':
        return const _MissingItem('Present address', 0);
      case 'permanentAddress':
        return const _MissingItem('Permanent address', 0);
      case 'location':
      case 'division':
      case 'district':
      case 'upazila':
      case 'union':
        return const _MissingItem('Location', 0);
      case 'country':
      case 'stateName':
      case 'cityName':
      case 'addressLine':
        return const _MissingItem('International address details', 0);
      default:
        return _MissingItem(field, 0);
    }
  }

  static _MissingItem _missingItemForDocument(String documentType) {
    switch (documentType) {
      case 'required_verification_document':
        return const _MissingItem('Primary verification document', 2);
      default:
        return _MissingItem(documentType, 2);
    }
  }
}

class _MissingItem {
  const _MissingItem(this.label, this.stepIndex);

  final String label;
  final int stepIndex;
}

class _DocTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onUpload;

  const _DocTile({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: busy ? null : onUpload,
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.currentStep,
    required this.totalSteps,
    required this.title,
  });

  final int currentStep;
  final int totalSteps;
  final String title;

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${currentStep + 1} of $totalSteps',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: progress.clamp(0, 1)),
      ],
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.step,
    required this.busy,
    required this.canGoBack,
    required this.onBack,
    required this.onSaveDraft,
    required this.onContinue,
    required this.continueLabel,
  });

  final int step;
  final bool busy;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onContinue;
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    final showBack = canGoBack && step > 0;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            if (showBack) ...[
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: busy ? null : onBack,
                    child: const Text(
                      'Back',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: busy ? null : onSaveDraft,
                  child: const Text(
                    'Save draft',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: busy ? null : onContinue,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            continueLabel,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
