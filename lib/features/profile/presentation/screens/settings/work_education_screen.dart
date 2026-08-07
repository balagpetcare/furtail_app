import 'package:flutter/material.dart';

import '../../../data/models/user_profile_model.dart';
import '../../../data/profile_service.dart';
import '../../widgets/settings_scaffold.dart';

/// Allowlisted Furtail profile fields: education, workStatus, profileType,
/// religiousStatus. Backend: PATCH /api/v1/user/me.
class WorkEducationScreen extends StatefulWidget {
  const WorkEducationScreen({super.key, required this.initial, this.profileService});
  final UserProfileModel initial;
  final ProfileService? profileService;

  @override
  State<WorkEducationScreen> createState() => _WorkEducationScreenState();
}

class _WorkEducationScreenState extends State<WorkEducationScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();
  late final TextEditingController _education = TextEditingController(
    text: widget.initial.education ?? '',
  );
  late final TextEditingController _workStatus = TextEditingController(
    text: widget.initial.workStatus ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_education, _workStatus]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_education, _workStatus]) {
      c.removeListener(_onFieldChanged);
    }
    _education.dispose();
    _workStatus.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _education.text.trim() != (widget.initial.education ?? '') ||
        _workStatus.text.trim() != (widget.initial.workStatus ?? '');
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _svc.updateProfile({
        'education': _education.text.trim().isEmpty ? null : _education.text.trim(),
        'workStatus': _workStatus.text.trim().isEmpty ? null : _workStatus.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Work and Education',
      hasUnsavedChanges: _hasUnsavedChanges,
      saveState: SettingsSaveState(saving: _saving, dirty: _hasUnsavedChanges, onSave: _save),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            SettingsErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _education,
            decoration: const InputDecoration(
              labelText: 'Education',
              prefixIcon: Icon(Icons.school_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _workStatus,
            decoration: const InputDecoration(
              labelText: 'Work',
              prefixIcon: Icon(Icons.work_outline),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
