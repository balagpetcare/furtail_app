import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/logout_reset.dart';
import '../../../../settings/presentation/providers/settings_providers.dart';
import '../../../data/profile_service.dart';
import '../../widgets/settings_scaffold.dart';

/// Deactivate / delete account, and data export.
/// Backend routes used (Central Auth):
/// - POST   /auth/deactivate  (requires password re-auth)
/// - DELETE /auth/me          (requires password re-auth, permanent)
///
/// Data download/export: no backend route exists yet. Shown as a disabled
/// "Coming later" item rather than a functional-looking dead control.
class DataAccountScreen extends ConsumerStatefulWidget {
  const DataAccountScreen({super.key, this.profileService});
  final ProfileService? profileService;

  @override
  ConsumerState<DataAccountScreen> createState() => _DataAccountScreenState();
}

class _DataAccountScreenState extends ConsumerState<DataAccountScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();
  bool _busy = false;

  Future<void> _afterAccountAction() async {
    await ref.read(settingsRepositoryProvider).logout();
    await resetSessionScopedState(ref);
    // !! NEVER navigate after resetSessionScopedState — AuthGate now owns
    // the navigation tree, matching the pattern used by the main logout flow.
  }

  Future<void> _deactivate() async {
    final password = await _promptPassword(
      title: 'Deactivate account',
      message:
          'Your profile will be hidden until you sign back in. Enter your password to confirm.',
      confirmLabel: 'Deactivate',
    );
    if (password == null) return;

    setState(() => _busy = true);
    try {
      await _svc.deactivateAccount(password: password);
      if (!mounted) return;
      await _afterAccountAction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final password = await _promptPassword(
      title: 'Delete account',
      message:
          'This permanently deletes your account and cannot be undone. Enter your password to confirm.',
      confirmLabel: 'Delete permanently',
      destructive: true,
    );
    if (password == null) return;

    setState(() => _busy = true);
    try {
      await _svc.deleteAccount(password: password);
      if (!mounted) return;
      await _afterAccountAction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      setState(() => _busy = false);
    }
  }

  Future<String?> _promptPassword({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _PasswordConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SettingsScaffold(
      title: 'Data and Account',
      scrollable: false,
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.6 : 1,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SettingsSectionLabel('Your data'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: false,
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download your data'),
                subtitle: const Text('Coming later'),
              ),
              const SizedBox(height: 24),

              const SettingsSectionLabel('Account'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pause_circle_outline),
                title: const Text('Deactivate account'),
                subtitle: const Text(
                  'Temporarily hide your profile. You can sign back in anytime.',
                ),
                onTap: _busy ? null : _deactivate,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_forever_outlined, color: colors.error),
                title: Text('Delete account', style: TextStyle(color: colors.error)),
                subtitle: const Text('Permanently delete your account and all data.'),
                onTap: _busy ? null : _delete,
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordConfirmDialog extends StatefulWidget {
  const _PasswordConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: widget.destructive ? Colors.red : null),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, _password.text);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
