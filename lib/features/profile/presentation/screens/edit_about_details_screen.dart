import 'package:flutter/material.dart';

import '../../data/models/user_profile_model.dart';
import '../../data/profile_service.dart';

class EditAboutDetailsScreen extends StatefulWidget {
  final UserProfileModel initial;
  const EditAboutDetailsScreen({super.key, required this.initial});

  @override
  State<EditAboutDetailsScreen> createState() => _EditAboutDetailsScreenState();
}

class _EditAboutDetailsScreenState extends State<EditAboutDetailsScreen> {
  final _svc = ProfileService();

  late final TextEditingController _education;
  late final TextEditingController _placeLive;
  late final TextEditingController _fansAndFriends;
  late final TextEditingController _from;
  late final TextEditingController _profileType;
  late final TextEditingController _workStatus;
  late final TextEditingController _religiousStatus;
  late final TextEditingController _gender;
  late final TextEditingController _maritalStatus;

  DateTime? _birthdate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _education = TextEditingController(text: p.education ?? '');
    _placeLive = TextEditingController(text: p.placeLive ?? '');
    _fansAndFriends = TextEditingController(text: p.fansAndFriends ?? '');
    _from = TextEditingController(text: p.from ?? '');
    _profileType = TextEditingController(text: p.profileType ?? '');
    _workStatus = TextEditingController(text: p.workStatus ?? '');
    _religiousStatus = TextEditingController(text: p.religiousStatus ?? '');
    _gender = TextEditingController(text: p.gender ?? '');
    _maritalStatus = TextEditingController(text: p.maritalStatus ?? '');
    _birthdate = p.birthdate;
  }

  @override
  void dispose() {
    _education.dispose();
    _placeLive.dispose();
    _fansAndFriends.dispose();
    _from.dispose();
    _profileType.dispose();
    _workStatus.dispose();
    _religiousStatus.dispose();
    _gender.dispose();
    _maritalStatus.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final initial = _birthdate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() => _birthdate = picked);
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Not set';
    return "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'education': _education.text.trim(),
        'placeLive': _placeLive.text.trim(),
        'fansAndFriends': _fansAndFriends.text.trim(),
        'from': _from.text.trim(),
        'profileType': _profileType.text.trim(),
        'workStatus': _workStatus.text.trim(),
        'religiousStatus': _religiousStatus.text.trim(),
        'gender': _gender.text.trim(),
        'maritalStatus': _maritalStatus.text.trim(),
        'birthdate': _birthdate?.toIso8601String(),
      };

      // send empty strings as null
      payload.removeWhere((k, v) => v == null);
      for (final k in payload.keys.toList()) {
        final v = payload[k];
        if (v is String && v.isEmpty) payload[k] = null;
      }

      await _svc.updateProfile(payload);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _hasUnsavedChanges {
    final p = widget.initial;
    if (_education.text != (p.education ?? '')) return true;
    if (_placeLive.text != (p.placeLive ?? '')) return true;
    if (_fansAndFriends.text != (p.fansAndFriends ?? '')) return true;
    if (_from.text != (p.from ?? '')) return true;
    if (_profileType.text != (p.profileType ?? '')) return true;
    if (_workStatus.text != (p.workStatus ?? '')) return true;
    if (_religiousStatus.text != (p.religiousStatus ?? '')) return true;
    if (_gender.text != (p.gender ?? '')) return true;
    if (_maritalStatus.text != (p.maritalStatus ?? '')) return true;
    if (_birthdate != p.birthdate) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit About Details'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: const _GreyBackButton(),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _saving ? Colors.grey : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          )
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_saving) return;
          if (!_hasUnsavedChanges) {
            Navigator.pop(context);
            return;
          }
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('Are you sure you want to discard your changes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: SafeArea(
          child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('Education', _education),
            _field('Place live', _placeLive),
            _field('Fans and friends', _fansAndFriends),
            _field('From', _from),
            _field('Profile type', _profileType),
            _field('Work status', _workStatus),
            _field('Religious status', _religiousStatus),
            _field('Gender', _gender),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Birthdate'),
              subtitle: Text(_fmt(_birthdate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickBirthdate,
            ),
            _field('Marital status', _maritalStatus),
            const SizedBox(height: 20),
            // Bottom save removed — AppBar "Save" is the primary action.
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Standard back button for white-background screens:
/// light grey circular background + dark icon.
class _GreyBackButton extends StatelessWidget {
  const _GreyBackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFE8EAED),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A2E)),
      ),
    );
  }
}
