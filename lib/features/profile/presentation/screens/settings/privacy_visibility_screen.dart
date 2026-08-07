import 'package:flutter/material.dart';

import '../../../data/models/user_profile_model.dart';
import '../../../data/profile_service.dart';
import '../../widgets/settings_scaffold.dart';

const _kVisibilityOptions = ['PUBLIC', 'FOLLOWERS_ONLY', 'PRIVATE'];

/// Profile visibility, followers/following visibility, contact visibility,
/// and discoverability. Persisted and enforced server-side.
/// Backend: PATCH /api/v1/user/me (allowlisted privacy fields).
class PrivacyVisibilityScreen extends StatefulWidget {
  const PrivacyVisibilityScreen({super.key, required this.initial, this.profileService});
  final UserProfileModel initial;
  final ProfileService? profileService;

  @override
  State<PrivacyVisibilityScreen> createState() => _PrivacyVisibilityScreenState();
}

class _PrivacyVisibilityScreenState extends State<PrivacyVisibilityScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();
  late UserProfileModel _model = widget.initial;
  final Set<String> _saving = {};
  String? _error;

  Future<void> _update(
    String field,
    dynamic value,
    UserProfileModel Function() applyLocally,
  ) async {
    final previous = _model;
    setState(() {
      _model = applyLocally();
      _saving.add(field);
      _error = null;
    });
    try {
      final updated = await _svc.updateProfile({field: value});
      if (!mounted) return;
      setState(() => _model = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _model = previous;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _saving.remove(field));
    }
  }

  Widget _visibilityDropdown({
    required String label,
    required String field,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: DropdownButton<String>(
        value: value,
        items: _kVisibilityOptions
            .map((v) => DropdownMenuItem(value: v, child: Text(_visibilityLabel(v))))
            .toList(),
        onChanged: _saving.contains(field)
            ? null
            : (v) {
                if (v == null) return;
                _update(field, v, () {
                  switch (field) {
                    case 'visibility':
                      return _model.copyWith(visibility: v);
                    case 'followersVisibility':
                      return _model.copyWith(followersVisibility: v);
                    default:
                      return _model;
                  }
                });
              },
      ),
    );
  }

  String _visibilityLabel(String v) {
    switch (v) {
      case 'PUBLIC':
        return 'Everyone';
      case 'FOLLOWERS_ONLY':
        return 'Followers only';
      case 'PRIVATE':
        return 'Only me';
      default:
        return v;
    }
  }

  Widget _boolSwitch({
    required String label,
    required String field,
    required bool value,
    required UserProfileModel Function(bool) applyLocally,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: _saving.contains(field) ? null : (v) => _update(field, v, () => applyLocally(v)),
      secondary: _saving.contains(field)
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Privacy and Visibility',
      body: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (_error != null) ...[
            SettingsErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          SettingsSectionLabel('Profile visibility'),
          _visibilityDropdown(
            label: 'Who can see your profile',
            field: 'visibility',
            value: _model.visibility,
          ),
          _visibilityDropdown(
            label: 'Who can see your followers',
            field: 'followersVisibility',
            value: _model.followersVisibility ?? 'PUBLIC',
          ),
          const SizedBox(height: 16),

          SettingsSectionLabel('Contact visibility'),
          _boolSwitch(
            label: 'Show email on profile',
            field: 'showEmail',
            value: _model.showEmail,
            applyLocally: (v) => _model.copyWith(showEmail: v),
          ),
          _boolSwitch(
            label: 'Show phone on profile',
            field: 'showPhone',
            value: _model.showPhone,
            applyLocally: (v) => _model.copyWith(showPhone: v),
          ),
          const SizedBox(height: 16),

          SettingsSectionLabel('Discoverability'),
          _boolSwitch(
            label: 'Discoverable by username search',
            field: 'discoverableBySearch',
            value: _model.discoverableBySearch ?? true,
            applyLocally: (v) => _model.copyWith(discoverableBySearch: v),
          ),
          _boolSwitch(
            label: 'Discoverable by email',
            field: 'discoverableByEmail',
            value: _model.discoverableByEmail ?? false,
            applyLocally: (v) => _model.copyWith(discoverableByEmail: v),
          ),
          _boolSwitch(
            label: 'Discoverable by phone',
            field: 'discoverableByPhone',
            value: _model.discoverableByPhone ?? false,
            applyLocally: (v) => _model.copyWith(discoverableByPhone: v),
          ),
          const SizedBox(height: 16),

          SettingsSectionLabel('Activity'),
          _boolSwitch(
            label: 'Show activity status',
            field: 'showActivityStatus',
            value: _model.showActivityStatus ?? false,
            applyLocally: (v) => _model.copyWith(showActivityStatus: v),
          ),
          _boolSwitch(
            label: 'Show read receipts',
            field: 'showReadReceipts',
            value: _model.showReadReceipts ?? false,
            applyLocally: (v) => _model.copyWith(showReadReceipts: v),
          ),
        ],
      ),
    );
  }
}
