import 'package:flutter/material.dart';

import '../../../../../core/auth/central_auth_api.dart';
import '../../../../../core/auth/session_recovery.dart';
import '../../../data/profile_service.dart';
import '../../widgets/section_error_state.dart';
import '../../widgets/settings_scaffold.dart';

/// Verified contacts, active sessions, and password change.
/// Backend routes used (Central Auth):
/// - GET    /auth/me
/// - GET    /auth/sessions
/// - DELETE /auth/sessions/:sessionId
/// - POST   /auth/sessions/logout-others
/// - POST   /auth/change-password
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key, this.profileService});
  final ProfileService? profileService;

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  late final ProfileService _svc = widget.profileService ?? ProfileService();

  CentralAuthUser? _identity;
  List<CentralAuthSession>? _sessions;
  Object? _identityError;
  Object? _sessionsError;
  bool _loadingIdentity = true;
  bool _loadingSessions = true;
  String? _busySessionId;
  bool _loggingOutOthers = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// Loads identity and sessions together. Both hit the same Central Auth
  /// session, so a single expired-token failure would otherwise surface as
  /// two separate raw error cards — [_sharedSessionFailure] collapses that
  /// into one banner instead.
  Future<void> _loadAll() async {
    await Future.wait([_loadIdentity(), _loadSessions()]);
  }

  /// True when both subsections failed for the same reason: the shared
  /// Central Auth session, not two unrelated problems.
  bool get _sharedSessionFailure =>
      _identityError is SessionRecoveryException && _sessionsError is SessionRecoveryException;

  Future<void> _loadIdentity() async {
    setState(() {
      _loadingIdentity = true;
      _identityError = null;
    });
    try {
      final identity = await _svc.getAccountIdentity();
      if (!mounted) return;
      setState(() => _identity = identity);
    } catch (e) {
      if (!mounted) return;
      setState(() => _identityError = e);
    } finally {
      if (mounted) setState(() => _loadingIdentity = false);
    }
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loadingSessions = true;
      _sessionsError = null;
    });
    try {
      final sessions = await _svc.listSessions();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sessionsError = e);
    } finally {
      if (mounted) setState(() => _loadingSessions = false);
    }
  }

  String _cleanError(Object e) =>
      e is SessionRecoveryException ? e.message : e.toString().replaceAll('Exception: ', '');

  Future<void> _revokeSession(CentralAuthSession session) async {
    setState(() => _busySessionId = session.id);
    try {
      await _svc.revokeSession(session.id);
      if (!mounted) return;
      setState(() => _sessions?.removeWhere((s) => s.id == session.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not revoke session: ${_cleanError(e)}')));
    } finally {
      if (mounted) setState(() => _busySessionId = null);
    }
  }

  Future<void> _logoutOtherDevices() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out other devices?'),
        content: const Text('This ends every session except the one you are using right now.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out others'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loggingOutOthers = true);
    try {
      await _svc.logoutAllOtherDevices();
      await _loadSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not log out other devices: ${_cleanError(e)}')));
    } finally {
      if (mounted) setState(() => _loggingOutOthers = false);
    }
  }

  Future<void> _openChangePassword() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(svc: _svc),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Account and Security',
      scrollable: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_sharedSessionFailure) ...[
            // One shared Central Auth session failure, one banner — not a
            // separate raw error card under contacts and another under
            // sessions for the exact same underlying cause.
            SectionErrorState(
              error: _identityError!,
              onRetry: _loadAll,
              title: 'Account details could not be loaded',
            ),
            const SizedBox(height: 24),
          ] else ...[
            SettingsSectionLabel('Verified contacts'),
            if (_loadingIdentity)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_identityError != null)
              SettingsErrorBanner(message: _cleanError(_identityError!), onRetry: _loadIdentity)
            else if (_identity != null)
              _IdentityCard(identity: _identity!),
            const SizedBox(height: 24),
          ],

          const SettingsSectionLabel('Password'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openChangePassword,
          ),
          const SizedBox(height: 24),

          if (!_sharedSessionFailure) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SettingsSectionLabel('Active sessions'),
                if (!_loadingSessions && (_sessions?.length ?? 0) > 1)
                  TextButton(
                    onPressed: _loggingOutOthers ? null : _logoutOtherDevices,
                    child: _loggingOutOthers
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Log out other devices'),
                  ),
              ],
            ),
            if (_loadingSessions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sessionsError != null)
              SettingsErrorBanner(message: _cleanError(_sessionsError!), onRetry: _loadSessions)
            else if ((_sessions ?? const []).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No active sessions found.'),
              )
            else
              ...(_sessions!.map(
                (s) => _SessionTile(
                  session: s,
                  busy: _busySessionId == s.id,
                  onRevoke: s.isCurrent ? null : () => _revokeSession(s),
                ),
              )),
          ],
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.identity});
  final CentralAuthUser identity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (identity.email != null) ...[
            Row(
              children: [
                Icon(Icons.email, size: 20, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    identity.email!,
                    style: TextStyle(fontWeight: FontWeight.w500, color: colors.onSurface),
                  ),
                ),
                Text(
                  identity.isEmailVerified ? 'Verified' : 'Unverified',
                  style: TextStyle(
                    color: identity.isEmailVerified ? colors.tertiary : colors.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Divider(color: colors.outlineVariant),
          ],
          Row(
            children: [
              Icon(Icons.phone, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  identity.phone ?? 'No phone added',
                  style: TextStyle(fontWeight: FontWeight.w500, color: colors.onSurface),
                ),
              ),
              if (identity.phone != null)
                Text(
                  identity.isPhoneVerified ? 'Verified' : 'Unverified',
                  style: TextStyle(
                    color: identity.isPhoneVerified ? colors.tertiary : colors.error,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.busy, this.onRevoke});
  final CentralAuthSession session;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (session.ipAddress != null) session.ipAddress!,
      if (session.lastActiveAt != null) 'Last active ${session.lastActiveAt}',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.devices_other),
      title: Text(session.clientName ?? session.userAgent ?? 'Unknown device'),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
      trailing: session.isCurrent
          ? const Chip(label: Text('This device'))
          : busy
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: onRevoke,
            ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.svc});
  final ProfileService svc;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.svc.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
        confirmPassword: _confirm.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Text(
                  _error is SessionRecoveryException
                      ? (_error! as SessionRecoveryException).message
                      : _error.toString().replaceAll('Exception: ', ''),
                  style: TextStyle(color: colors.error),
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
              ),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
                validator: (v) => v != _next.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
