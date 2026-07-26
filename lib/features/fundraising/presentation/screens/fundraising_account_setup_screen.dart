// ignore_for_file: deprecated_member_use, unused_element

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

  // IDs
  final _nidCtrl = TextEditingController();
  final _birthRegCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();

  DateTime? _dob;

  // Location dropdown selections
  int? _divisionId;
  int? _districtId;
  int? _upazilaId;
  int? _unionId;
  int? _areaId;
  String? _divisionName;
  String? _districtName;
  String? _upazilaName;
  String? _unionName;
  String? _areaName;

  // Organization-only fields
  final _orgNameCtrl = TextEditingController();
  final _orgDescCtrl = TextEditingController();
  final _orgWorkTypeCtrl = TextEditingController();

  bool _saving = false;
  bool _busyDoc = false;
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
    _presentAddressCtrl.dispose();
    _permanentAddressCtrl.dispose();
    _occupationCtrl.dispose();
    _nidCtrl.dispose();
    _birthRegCtrl.dispose();
    _studentIdCtrl.dispose();
    _passportCtrl.dispose();
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
    _presentAddressCtrl.clear();
    _permanentAddressCtrl.clear();
    _occupationCtrl.clear();
    _nidCtrl.clear();
    _birthRegCtrl.clear();
    _studentIdCtrl.clear();
    _passportCtrl.clear();
    _dob = null;
    _divisionId = null;
    _districtId = null;
    _upazilaId = null;
    _unionId = null;
    _areaId = null;
    _divisionName = null;
    _districtName = null;
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
    if (a == null) return;
    _prefilled = true;

    _accountType = (a.accountType == null || a.accountType!.isEmpty)
        ? 'INDIVIDUAL'
        : a.accountType!;
    _presentAddressCtrl.text = a.presentAddress ?? '';
    _permanentAddressCtrl.text = a.permanentAddress ?? '';
    _occupationCtrl.text = a.occupation ?? '';

    _nidCtrl.text = a.nationalIdNumber ?? '';
    _birthRegCtrl.text = a.birthRegNumber ?? '';
    _studentIdCtrl.text = a.studentIdNumber ?? '';
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
      _upazilaId = a.upazilaId;
      _unionId = a.unionId;
      _areaId = a.areaId;
    }

    // Names might not be present; UI will still work without them.
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 80, 1, 1),
      lastDate: DateTime(now.year - 10, 12, 31),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() => _dob = DateTime(picked.year, picked.month, picked.day));
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
      'upazilaId': _upazilaId,
      'unionId': _unionId,
      'areaId': _areaId,
      'divisionName': _divisionName,
      'districtName': _districtName,
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
    _upazilaId = fundraisingInt(data['upazilaId']) ?? _upazilaId;
    _unionId = fundraisingInt(data['unionId']) ?? _unionId;
    _areaId = fundraisingInt(data['areaId']) ?? _areaId;
    _divisionName = (data['divisionName'] ?? _divisionName)?.toString();
    _districtName = (data['districtName'] ?? _districtName)?.toString();
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
    try {
      await ref
          .read(bdLocationsRepositoryProvider)
          .validateSelection(
            divisionId: _divisionId,
            districtId: _districtId,
            upazilaId: _upazilaId,
            unionId: _unionId,
            areaId: _areaId,
          );
    } on ApiClientException catch (error) {
      final code = (error.code ?? '').toUpperCase();
      const knownMismatchCodes = <String>{
        'DISTRICT_DIVISION_MISMATCH',
        'UPAZILA_DISTRICT_MISMATCH',
        'UNION_UPAZILA_MISMATCH',
        'AREA_UNION_MISMATCH',
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
        if (code == 'DISTRICT_DIVISION_MISMATCH') {
          _districtId = null;
          _districtName = null;
          _upazilaId = null;
          _upazilaName = null;
          _unionId = null;
          _unionName = null;
          _areaId = null;
          _areaName = null;
        } else if (code == 'UPAZILA_DISTRICT_MISMATCH') {
          _upazilaId = null;
          _upazilaName = null;
          _unionId = null;
          _unionName = null;
          _areaId = null;
          _areaName = null;
        } else if (code == 'UNION_UPAZILA_MISMATCH' ||
            code == 'AREA_UNION_MISMATCH' ||
            code == 'LOCATION_ID_NOT_FOUND') {
          _unionId = null;
          _unionName = null;
          _areaId = null;
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
      default:
        return _nidCtrl.text.trim().isNotEmpty ||
            _birthRegCtrl.text.trim().isNotEmpty ||
            _passportCtrl.text.trim().isNotEmpty ||
            _studentIdCtrl.text.trim().isNotEmpty;
    }
  }

  bool _hasPrimaryVerificationDocument() {
    final docs = _account?.documents ?? const <FundraisingAccountDocument>[];
    return docs.any((doc) => _isPrimaryDocumentTitle(doc.title));
  }

  bool _isPrimaryDocumentTitle(String title) {
    final text = title.trim().toLowerCase();
    return text.contains('verification') ||
        text.contains('primary') ||
        text.contains('nid') ||
        text.contains('national id') ||
        text.contains('birth') ||
        text.contains('passport') ||
        text.contains('driving');
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
        return _divisionId != null &&
            _districtId != null &&
            _upazilaId != null &&
            (_unionId != null || _areaId != null) &&
            _presentAddressCtrl.text.trim().isNotEmpty &&
            _permanentAddressCtrl.text.trim().isNotEmpty;
      case 1:
        return _dob != null &&
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
      await ref
          .read(bdLocationsRepositoryProvider)
          .validateSelection(
            divisionId: _divisionId,
            districtId: _districtId,
            upazilaId: _upazilaId,
            unionId: _unionId,
            areaId: _areaId,
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
    return <String, dynamic>{
      'accountType': _accountType,
      'presentAddress': _presentAddressCtrl.text.trim(),
      'permanentAddress': permanent,
      'occupation': _occupationCtrl.text.trim(),
      'divisionId': _isGlobalMode ? null : _divisionId,
      'districtId': _isGlobalMode ? null : _districtId,
      'upazilaId': _isGlobalMode ? null : _upazilaId,
      'unionId': _isGlobalMode ? null : _unionId,
      'areaId': _isGlobalMode ? null : _areaId,
      'area': _isGlobalMode ? null : (_unionName ?? _areaName),
      'countryCode': _isGlobalMode ? 'GL' : 'BD',
      'countryName': _isGlobalMode ? _countryNameCtrl.text.trim() : null,
      'stateName': _isGlobalMode ? _stateNameCtrl.text.trim() : null,
      'cityName': _isGlobalMode ? _cityNameCtrl.text.trim() : null,
      'addressLine': _isGlobalMode ? _addressLineCtrl.text.trim() : null,
      'latitude': _isGlobalMode ? _latitude : null,
      'longitude': _isGlobalMode ? _longitude : null,
      'formattedAddress': _isGlobalMode ? _formattedAddress : null,
      'dateOfBirth': _dob?.toIso8601String(),
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
      if (_accountType == 'ORGANIZATION') 'orgName': _orgNameCtrl.text.trim(),
      if (_accountType == 'ORGANIZATION')
        'orgDescription': _orgDescCtrl.text.trim(),
      if (_accountType == 'ORGANIZATION')
        'orgWorkType': _orgWorkTypeCtrl.text.trim(),
      'verificationDraftJson': _snapshotRecovery(),
    };
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
                busy: _saving || _busyDoc,
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
        return _buildStepTwo(context, currentUser);
      case 2:
        return _buildStepThree(context, readiness);
      case 3:
        return _buildStepFour(context, readiness, currentUser);
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
              upazilaId: _upazilaId,
              unionId: _unionId,
              areaId: _areaId,
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
                        _unionId = id;
                        _unionName = name;
                        _areaId = null;
                        _areaName = null;
                        _hasUnsavedChanges = true;
                      });
                    },
              onAreaChanged: _saving
                  ? null
                  : (id, name) {
                      setState(() {
                        _areaId = id;
                        _areaName = name;
                        _unionId = null;
                        _unionName = null;
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

  Widget _buildStepTwo(BuildContext context, CurrentUser currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Identity details'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade100,
          ),
          child: Text(
            currentUser.name.trim().isEmpty
                ? 'Full name will be taken from your profile.'
                : 'Full name: ${currentUser.name}',
          ),
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
    String title,
  ) async {
    await _uploadRequiredDoc(title, replaceDocument: document);
  }

  Future<void> _removeDocument(FundraisingAccountDocument document) async {
    if (_busyDoc) return;
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
    setState(() => _busyDoc = true);
    try {
      await ref.read(fundraisingRepositoryProvider).deleteDocument(document.id);
      ref.invalidate(fundraisingMyAccountProvider);
      await _loadAccount(keepVisibleWhileLoading: true);
      await _persistRecovery();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFundraisingSafeError(error).message)),
      );
    } finally {
      if (mounted) setState(() => _busyDoc = false);
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

  Widget _buildDocumentCard(
    String title,
    String subtitle,
    List<FundraisingAccountDocument> docs, {
    required bool requiredDocument,
  }) {
    final t = AppLocalizations.of(context)!;
    final document = docs.isNotEmpty ? docs.first : null;
    final statusLabel = document == null
        ? (requiredDocument ? t.fundraisingRequired : t.fundraisingOptional)
        : t.fundraisingUploaded;
    final statusVariant = document == null
        ? (requiredDocument
              ? FundraisingChipVariant.warning
              : FundraisingChipVariant.neutral)
        : FundraisingChipVariant.success;
    final actions = <Widget>[
      if (document != null)
        TextButton(
          onPressed: () => _previewVerificationDocument(document),
          child: const Text('View'),
        ),
      TextButton(
        onPressed: _busyDoc
            ? null
            : () => document == null
                  ? _uploadRequiredDoc(title)
                  : _replaceDocument(document, title),
        child: Text(document == null ? 'Upload' : 'Replace'),
      ),
      if (document != null)
        TextButton(
          onPressed: _busyDoc ? null : () => _removeDocument(document),
          child: const Text('Remove'),
        ),
    ];

    return FundraisingSectionCard(
      title: title,
      subtitle: subtitle,
      trailing: FundraisingStatusChip(
        label: statusLabel,
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
                  'Uploaded ${document.createdAt!.toLocal()}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
          ],
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
    CurrentUser currentUser,
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
              'Full name: ${currentUser.name}\nOccupation: ${_occupationCtrl.text.trim()}\nDate of birth: ${_dob == null ? 'Not set' : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'}',
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
        _VerificationSummary(readiness: readiness),
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
  }) async {
    if (_busyDoc) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _busyDoc = true);
    try {
      final mediaId = await _postsDs.uploadMedia(File(path));
      final repo = ref.read(fundraisingRepositoryProvider);
      await repo.addDocument(title: title, mediaId: mediaId);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFundraisingSafeError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _busyDoc = false);
    }
  }

  bool _hasAnyIdNumber() {
    return _nidCtrl.text.trim().isNotEmpty ||
        _birthRegCtrl.text.trim().isNotEmpty ||
        _studentIdCtrl.text.trim().isNotEmpty;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth is required')),
      );
      return;
    }

    if (_isGlobalMode) {
      if (_countryNameCtrl.text.isEmpty || _addressLineCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Country and Address are required')),
        );
        return;
      }
    } else {
      if (_divisionId == null ||
          _districtId == null ||
          _upazilaId == null ||
          (_unionId == null && _areaId == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select Division, District, Upazila, and Union / Ward',
            ),
          ),
        );
        return;
      }
    }

    if (!_hasAnyIdNumber()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide at least one ID number (NID / Birth Reg / Student ID)',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);
      final payload = <String, dynamic>{
        'accountType': _accountType,
        'presentAddress': _presentAddressCtrl.text.trim(),
        'permanentAddress': _permanentAddressCtrl.text.trim(),
        'occupation': _occupationCtrl.text.trim(),
        'divisionId': _isGlobalMode ? null : _divisionId,
        'districtId': _isGlobalMode ? null : _districtId,
        'upazilaId': _isGlobalMode ? null : _upazilaId,
        'unionId': _isGlobalMode ? null : _unionId,
        'areaId': _isGlobalMode ? null : _areaId,
        'area': _isGlobalMode ? null : (_areaName ?? _unionName),
        'countryCode': _isGlobalMode ? 'GL' : 'BD',
        'countryName': _isGlobalMode ? _countryNameCtrl.text.trim() : null,
        'stateName': _isGlobalMode ? _stateNameCtrl.text.trim() : null,
        'cityName': _isGlobalMode ? _cityNameCtrl.text.trim() : null,
        'addressLine': _isGlobalMode ? _addressLineCtrl.text.trim() : null,
        'latitude': _isGlobalMode ? _latitude : null,
        'longitude': _isGlobalMode ? _longitude : null,
        'formattedAddress': _isGlobalMode ? _formattedAddress : null,
        'dateOfBirth': _dob?.toIso8601String(),
        'nationalIdNumber': _nidCtrl.text.trim().isEmpty
            ? null
            : _nidCtrl.text.trim(),
        'birthRegNumber': _birthRegCtrl.text.trim().isEmpty
            ? null
            : _birthRegCtrl.text.trim(),
        'studentIdNumber': _studentIdCtrl.text.trim().isEmpty
            ? null
            : _studentIdCtrl.text.trim(),
      };

      if (_accountType == 'ORGANIZATION') {
        payload['orgName'] = _orgNameCtrl.text.trim();
        payload['orgDescription'] = _orgDescCtrl.text.trim();
        payload['orgWorkType'] = _orgWorkTypeCtrl.text.trim();
      }

      final updated = await repo.updateMyAccount(payload);
      ref.invalidate(fundraisingMyAccountProvider);
      await _loadAccount();

      if (!mounted) return;
      final refreshed = _account ?? updated;
      if (refreshed.readiness.canStartFundraiser) {
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification info saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFundraisingSafeError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
                      _VerificationSummary(readiness: readiness),
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
                        areaId: _areaId,
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
                            : (id, name) {
                                setState(() {
                                  _areaId = id;
                                  _areaName = name;
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
                  _VerificationSummary(readiness: readiness),
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
                    areaId: _areaId,
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
                        : (id, name) {
                            setState(() {
                              _areaId = id;
                              _areaName = name;
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
    String text;
    String hint;
    IconData icon = Icons.hourglass_bottom;

    switch (status) {
      case 'VERIFIED':
        text = t.fundraisingEligibilityVerified;
        hint = t.fundraisingEligibilitySummaryVerified;
        icon = Icons.verified;
        break;
      case 'REJECTED':
        text = t.fundraisingEligibilityRejected;
        hint = t.fundraisingEligibilitySummaryRejected;
        icon = Icons.error_outline;
        break;
      case 'SUSPENDED':
      case 'BLOCKED':
        text = t.fundraisingEligibilityRestricted;
        hint = t.fundraisingEligibilitySummaryRestricted;
        icon = Icons.block;
        break;
      case 'PENDING':
      case 'PENDING_REVIEW':
        if (readiness.canStartFundraiser) {
          text = t.fundraisingEligibilityPending;
          hint = t.fundraisingEligibilitySummaryPending;
        } else {
          text = t.fundraisingEligibilityDraft;
          hint = t.fundraisingEligibilitySummaryActionRequired;
        }
        break;
      case 'DRAFT':
        if (readiness.canStartFundraiser) {
          text = t.fundraisingEligibilityPending;
          hint = t.fundraisingEligibilitySummaryPending;
        } else {
          text = t.fundraisingEligibilityDraft;
          hint = t.fundraisingEligibilitySummaryActionRequired;
        }
        break;
      default:
        text = t.fundraisingEligibilityDraft;
        hint = t.fundraisingEligibilitySummaryActionRequired;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(hint, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationSummary extends StatelessWidget {
  const _VerificationSummary({required this.readiness});

  final FundraisingAccountReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final missingProfile = readiness.missingProfileFields
        .map(_labelForField)
        .toList();
    final missingDocuments = readiness.missingDocumentTypes
        .map(_labelForDocument)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        border: Border.all(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What still needs attention',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (missingProfile.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Missing profile fields: ${missingProfile.join(', ')}'),
          ],
          if (missingDocuments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Missing documents: ${missingDocuments.join(', ')}'),
          ],
          if (readiness.isRejected &&
              readiness.safeRejectionReason != null) ...[
            const SizedBox(height: 6),
            Text(readiness.safeRejectionReason!),
          ],
          if (readiness.isPendingReview) ...[
            const SizedBox(height: 6),
            Text(
              readiness.canStartFundraiser
                  ? 'Verification pending does not block fundraiser creation.'
                  : 'Complete the required items to continue.',
            ),
          ],
        ],
      ),
    );
  }

  static String _labelForField(String field) {
    switch (field) {
      case 'presentAddress':
        return 'present address';
      case 'permanentAddress':
        return 'permanent address';
      case 'location':
        return 'location';
      case 'dateOfBirth':
        return 'date of birth';
      default:
        return field;
    }
  }

  static String _labelForDocument(String documentType) {
    switch (documentType) {
      case 'required_verification_document':
        return 'verification document';
      default:
        return documentType;
    }
  }
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
