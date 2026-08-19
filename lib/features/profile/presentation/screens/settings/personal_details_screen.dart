import 'package:flutter/material.dart';

import '../../../../../core/auth/central_auth_api.dart';
import '../../../../../core/auth/session_recovery.dart';
import '../../../data/profile_service.dart';
import '../../widgets/section_error_state.dart';
import '../../widgets/settings_scaffold.dart';

/// Canonical identity fields — firstName, lastName, dateOfBirth — owned by
/// Central Auth. Never PATCHes these through the Furtail profile endpoint.
class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key, this.profileService});
  final ProfileService? profileService;

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _dob;

  CentralAuthUser? _identity;
  Object? _loadError;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Without these, typing in either field never flips `_hasUnsavedChanges`
    // reactively — the Save button (which is disabled while `!dirty`, see
    // SettingsScaffold) would stay disabled until some unrelated rebuild
    // happened to occur.
    _firstName.addListener(_onFieldChanged);
    _lastName.addListener(_onFieldChanged);
    _load();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final identity = await _svc.getAccountIdentity();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _firstName.text = identity.firstName ?? '';
        _lastName.text = identity.lastName ?? '';
        _dob = identity.dateOfBirth;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstName.removeListener(_onFieldChanged);
    _lastName.removeListener(_onFieldChanged);
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    if (_identity == null) return false;
    if (_firstName.text.trim() != (_identity!.firstName ?? '')) return true;
    if (_lastName.text.trim() != (_identity!.lastName ?? '')) return true;
    if (_dob != _identity!.dateOfBirth) return true;
    return false;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final updated = await _svc.updateIdentity(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        dateOfBirth: _dob,
      );
      if (!mounted) return;
      setState(() => _identity = updated);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = e is SessionRecoveryException
          ? e.message
          : e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'This field is required' : null;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SettingsScaffold(
        title: 'Personal Details',
        scrollable: false,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return SettingsScaffold(
        title: 'Personal Details',
        scrollable: false,
        body: Center(
          child: SectionErrorState(
            error: _loadError!,
            onRetry: _load,
            title: 'Personal details could not be loaded',
          ),
        ),
      );
    }
    return SettingsScaffold(
      title: 'Personal Details',
      hasUnsavedChanges: _hasUnsavedChanges,
      saveState: SettingsSaveState(
        saving: _saving,
        dirty: _hasUnsavedChanges,
        onSave: _save,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _firstName,
              validator: _required,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'First name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              validator: _required,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Last name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth'),
              subtitle: Text(
                _dob != null
                    ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
                    : 'Not set',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDob,
            ),
          ],
        ),
      ),
    );
  }
}
