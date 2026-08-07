import 'package:flutter/material.dart';

import '../../../data/models/user_profile_model.dart';
import '../../../data/profile_service.dart';
import '../../widgets/settings_scaffold.dart';

const _kInteractionOptions = ['EVERYONE', 'FOLLOWERS', 'NOBODY'];

/// Who can follow/message/comment/mention/tag you, and tag review.
/// Persisted and enforced server-side (whoCanFollow, whoCanComment already
/// enforced in follow/comment routes; discoverableBySearch enforced too).
/// Backend: PATCH /api/v1/user/me (allowlisted interaction fields).
class SocialInteractionsScreen extends StatefulWidget {
  const SocialInteractionsScreen({super.key, required this.initial, this.profileService});
  final UserProfileModel initial;
  final ProfileService? profileService;

  @override
  State<SocialInteractionsScreen> createState() => _SocialInteractionsScreenState();
}

class _SocialInteractionsScreenState extends State<SocialInteractionsScreen> {
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

  String _optionLabel(String v) {
    switch (v) {
      case 'EVERYONE':
        return 'Everyone';
      case 'FOLLOWERS':
        return 'Followers only';
      case 'NOBODY':
        return 'Nobody';
      default:
        return v;
    }
  }

  Widget _interactionDropdown({
    required String label,
    required String field,
    required String value,
    required UserProfileModel Function(String) applyLocally,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: DropdownButton<String>(
        value: value,
        items: _kInteractionOptions
            .map((v) => DropdownMenuItem(value: v, child: Text(_optionLabel(v))))
            .toList(),
        onChanged: _saving.contains(field)
            ? null
            : (v) {
                if (v == null) return;
                _update(field, v, () => applyLocally(v));
              },
      ),
    );
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
      title: 'Social Interactions',
      body: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (_error != null) ...[
            SettingsErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          const SettingsSectionLabel('Who can interact with you'),
          _interactionDropdown(
            label: 'Follow you',
            field: 'whoCanFollow',
            value: _model.whoCanFollow ?? 'EVERYONE',
            applyLocally: (v) => _model.copyWith(whoCanFollow: v),
          ),
          _interactionDropdown(
            label: 'Message you',
            field: 'whoCanMessage',
            value: _model.whoCanMessage ?? 'EVERYONE',
            applyLocally: (v) => _model.copyWith(whoCanMessage: v),
          ),
          _interactionDropdown(
            label: 'Comment on your posts',
            field: 'whoCanComment',
            value: _model.whoCanComment ?? 'EVERYONE',
            applyLocally: (v) => _model.copyWith(whoCanComment: v),
          ),
          _interactionDropdown(
            label: 'Mention you',
            field: 'whoCanMention',
            value: _model.whoCanMention ?? 'EVERYONE',
            applyLocally: (v) => _model.copyWith(whoCanMention: v),
          ),
          _interactionDropdown(
            label: 'Tag you',
            field: 'whoCanTag',
            value: _model.whoCanTag ?? 'EVERYONE',
            applyLocally: (v) => _model.copyWith(whoCanTag: v),
          ),
          const SizedBox(height: 16),

          const SettingsSectionLabel('Review before posting'),
          _boolSwitch(
            label: 'Review tags before they appear on your profile',
            field: 'requiresTagReview',
            value: _model.requiresTagReview ?? false,
            applyLocally: (v) => _model.copyWith(requiresTagReview: v),
          ),
          _boolSwitch(
            label: 'Review posts others make on your profile',
            field: 'requiresProfilePostReview',
            value: _model.requiresProfilePostReview ?? false,
            applyLocally: (v) => _model.copyWith(requiresProfilePostReview: v),
          ),
        ],
      ),
    );
  }
}
