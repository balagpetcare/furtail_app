import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/providers/current_user_provider.dart';
import '../../../../../services/api_client.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/profile_service.dart';
import '../../../data/profile_validation.dart';
import '../../widgets/settings_scaffold.dart';

/// Public profile — displayName, username, bio. Owned entirely by Furtail;
/// this screen never calls Central Auth to load or save anything.
class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.initial, this.profileService});
  final UserProfileModel initial;
  final ProfileService? profileService;

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _bio;

  bool _saving = false;
  String? _formError;
  String? _usernameFieldError;
  String? _bioFieldError;
  bool _usernameWasEmailDerived = false;

  @override
  void initState() {
    super.initState();
    final initialUsername = widget.initial.username ?? '';
    _usernameWasEmailDerived = ProfileValidation.looksEmailDerived(initialUsername);
    _displayName = TextEditingController(text: widget.initial.name);
    // A legacy email-derived username is a private repair state, never a
    // real public username — the field starts empty so the user must
    // deliberately choose a real one instead of unknowingly keeping it.
    _username = TextEditingController(text: _usernameWasEmailDerived ? '' : initialUsername);
    _bio = TextEditingController(text: widget.initial.bio ?? '');
    for (final c in [_displayName, _username, _bio]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_displayName, _username, _bio]) {
      c.removeListener(_onFieldChanged);
    }
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    final p = widget.initial;
    if (_displayName.text.trim() != p.name) return true;
    final baselineUsername = _usernameWasEmailDerived ? '' : (p.username ?? '');
    if (_username.text.trim() != baselineUsername) return true;
    if (_bio.text.trim() != (p.bio ?? '')) return true;
    return false;
  }

  String? _fieldFromError(Object e) {
    if (e is! ApiClientException) return null;
    final data = e.responseData;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final details = error['details'];
        if (details is Map && details['field'] is String) {
          return details['field'] as String;
        }
      }
    }
    return null;
  }

  String _cleanMessage(Object e) {
    if (e is ApiClientException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _formError = null;
      _usernameFieldError = null;
      _bioFieldError = null;
    });

    try {
      final payload = <String, dynamic>{
        'displayName': _displayName.text.trim(),
        'username': _username.text.trim().isEmpty ? null : _username.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      };

      final updated = await _svc.updateProfile(payload);

      final sp = await SharedPreferences.getInstance();
      await sp.setString('userName', updated.name);
      await ref.read(currentUserProvider.notifier).reloadFromPrefs();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final field = _fieldFromError(e);
      final message = _cleanMessage(e);
      setState(() {
        // Dirty values are never cleared on failure — the user retypes
        // nothing, they only see what went wrong.
        if (field == 'username') {
          _usernameFieldError = message;
        } else if (field == 'bio') {
          _bioFieldError = message;
        } else {
          _formError = message;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) {
    if ((v ?? '').trim().isEmpty) return 'This field is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SettingsScaffold(
      title: 'Public profile',
      hasUnsavedChanges: _hasUnsavedChanges,
      saveState: SettingsSaveState(saving: _saving, dirty: _hasUnsavedChanges, onSave: _save),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_formError != null) ...[
              SettingsErrorBanner(message: _formError!),
              const SizedBox(height: 16),
            ],
            if (_usernameWasEmailDerived && _username.text.trim().isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email, color: colors.onSecondaryContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Choose a username — your current one isn\'t public yet.',
                        style: TextStyle(color: colors.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SettingsSectionLabel('Profile Basics'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _displayName,
              validator: _required,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                helperText: 'Your full name or nickname',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              validator: ProfileValidation.validateUsername,
              onChanged: (_) {
                if (_usernameFieldError != null) {
                  setState(() => _usernameFieldError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'e.g. pawlover99',
                helperText: ProfileValidation.usernameHelperText,
                errorText: _usernameFieldError,
                prefixIcon: const Icon(Icons.alternate_email),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: ProfileValidation.bioMaxLength,
              validator: ProfileValidation.validateBio,
              onChanged: (_) {
                if (_bioFieldError != null) {
                  setState(() => _bioFieldError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell people a little about yourself...',
                helperText: 'Up to ${ProfileValidation.bioMaxLength} characters',
                errorText: _bioFieldError,
                prefixIcon: const Icon(Icons.notes_rounded),
                border: const OutlineInputBorder(),
              ),
            ),

            SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ],
        ),
      ),
    );
  }
}
