import 'dart:io';

import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:bpa_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:bpa_app/features/location/presentation/widgets/location_selector_widget.dart';

import 'package:latlong2/latlong.dart';
import 'package:bpa_app/features/location/presentation/location_picker_screen.dart';

import '../providers/fundraising_providers.dart';
import '../../data/models/fundraising_models.dart';
import 'fundraising_account_documents_screen.dart';

/// Fundraising Account Verification (KYC) screen
/// - User can submit info + upload documents.
/// - Even if status is PENDING, user can still create fundraising posts,
///   but they MUST fill this form + upload docs at least once.
class FundraisingAccountSetupScreen extends ConsumerStatefulWidget {
  const FundraisingAccountSetupScreen({super.key});

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
  void dispose() {
    _presentAddressCtrl.dispose();
    _permanentAddressCtrl.dispose();
    _occupationCtrl.dispose();
    _nidCtrl.dispose();
    _birthRegCtrl.dispose();
    _studentIdCtrl.dispose();
    _orgNameCtrl.dispose();
    _orgDescCtrl.dispose();
    _orgWorkTypeCtrl.dispose();
    _countryNameCtrl.dispose();
    _stateNameCtrl.dispose();
    _cityNameCtrl.dispose();
    _addressLineCtrl.dispose();
    super.dispose();
  }

  void _prefill(FundraisingAccount a) {
    if (_prefilled) return;
    _prefilled = true;

    _accountType = a.accountType.isEmpty ? 'INDIVIDUAL' : a.accountType;
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
        builder:
            (_) => LocationPickerScreen(
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

  Future<void> _uploadRequiredDoc(String title) async {
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
      ref.invalidate(fundraisingMyAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
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
      if (_divisionId == null || _districtId == null || _upazilaId == null || _unionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Division, District, Upazila, and Union')),
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
      };

      if (_accountType == 'ORGANIZATION') {
        payload['orgName'] = _orgNameCtrl.text.trim();
        payload['orgDescription'] = _orgDescCtrl.text.trim();
        payload['orgWorkType'] = _orgWorkTypeCtrl.text.trim();
      }

      await repo.updateMyAccount(payload);
      ref.invalidate(fundraisingMyAccountProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification info saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myAcc = ref.watch(fundraisingMyAccountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Fundraising Verification'),
      ),
      body: myAcc.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed: $e')),
        data: (acc) {
          _prefill(acc);

          final status = acc.status.toUpperCase();
          final docs = acc.documents;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusBanner(status: status),
                    const SizedBox(height: 14),

                    // Account type
                    DropdownButtonFormField<String>(
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

                    // Location Mode Toggle
                    SwitchListTile(
                      title: const Text('Global / International Location'),
                      subtitle: const Text('Enable this if you are outside Bangladesh'),
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
                        disabled: _saving,
                        required: true,
                        onDivisionChanged: _saving
                            ? null
                            : (id, name) {
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
                              },
                        onDistrictChanged: _saving
                            ? null
                            : (id, name) {
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
                              },
                        onUnionChanged: _saving
                            ? null
                            : (id, name) {
                                setState(() {
                                  _unionId = id;
                                  _unionName = name;
                                  _areaId = null;
                                  _areaName = name;
                                });
                              },
                      ),
                    ] else ...[
                      // Global Fields
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
                    const SizedBox(height: 12),

                    // Addresses
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
                        style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
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

                    // Documents
                    Text(
                      'Required documents',
                      style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _DocTile(
                      title:
                          'National ID card (Front/Back) OR Birth Registration',
                      subtitle: 'Upload photo/scan (jpg/png/pdf)',
                      busy: _busyDoc,
                      onUpload: () =>
                          _uploadRequiredDoc('NID / Birth Registration'),
                    ),
                    const SizedBox(height: 8),
                    _DocTile(
                      title: 'Selfie / Profile photo (Clear)',
                      subtitle: 'A clear face photo for matching',
                      busy: _busyDoc,
                      onUpload: () => _uploadRequiredDoc('Selfie Photo'),
                    ),
                    const SizedBox(height: 8),
                    _DocTile(
                      title: 'School/College ID (Optional)',
                      subtitle: 'If applicable',
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
                      if (docs.length > 6)
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
                        'No documents uploaded yet. Please upload at least one document.',
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const FundraisingAccountDocumentsScreen(),
                          ),
                        ),
                        child: const Text('Open document manager'),
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
                      label: const Text('Save verification info'),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'Note: You can create fundraising posts even while verification is pending. '
                      'But you must fill this form and upload documents first.',
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
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    String text = 'Verification status: $status';
    String hint = 'Admin will review your documents and approve/reject later.';
    IconData icon = Icons.hourglass_bottom;

    if (status == 'VERIFIED') {
      icon = Icons.verified;
      hint = 'Your account is verified.';
    } else if (status == 'REJECTED') {
      icon = Icons.error_outline;
      hint =
          'Your verification was rejected. Please update info and documents.';
    } else if (status == 'PENDING') {
      icon = Icons.hourglass_bottom;
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
