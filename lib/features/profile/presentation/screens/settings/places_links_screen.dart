import 'package:flutter/material.dart';

import '../../../data/models/user_profile_model.dart';
import '../../../data/profile_service.dart';
import '../../widgets/settings_scaffold.dart';

/// Allowlisted Furtail profile fields: placeLive, from.
/// Backend: PATCH /api/v1/user/me.
///
/// Social/external links: no backend field exists yet — shown as an honest
/// disabled "Coming later" item rather than a functional-looking dead control.
class PlacesLinksScreen extends StatefulWidget {
  const PlacesLinksScreen({super.key, required this.initial, this.profileService});
  final UserProfileModel initial;
  final ProfileService? profileService;

  @override
  State<PlacesLinksScreen> createState() => _PlacesLinksScreenState();
}

class _PlacesLinksScreenState extends State<PlacesLinksScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();
  late final TextEditingController _placeLive = TextEditingController(
    text: widget.initial.placeLive ?? '',
  );
  late final TextEditingController _from = TextEditingController(text: widget.initial.from ?? '');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_placeLive, _from]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_placeLive, _from]) {
      c.removeListener(_onFieldChanged);
    }
    _placeLive.dispose();
    _from.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _placeLive.text.trim() != (widget.initial.placeLive ?? '') ||
        _from.text.trim() != (widget.initial.from ?? '');
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _svc.updateProfile({
        'placeLive': _placeLive.text.trim().isEmpty ? null : _placeLive.text.trim(),
        'from': _from.text.trim().isEmpty ? null : _from.text.trim(),
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
      title: 'Places and Links',
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
            controller: _placeLive,
            decoration: const InputDecoration(
              labelText: 'Current city',
              prefixIcon: Icon(Icons.place_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _from,
            decoration: const InputDecoration(
              labelText: 'Hometown',
              prefixIcon: Icon(Icons.home_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: false,
            leading: const Icon(Icons.link_outlined),
            title: const Text('Social and external links'),
            subtitle: const Text('Coming later'),
          ),
        ],
      ),
    );
  }
}
