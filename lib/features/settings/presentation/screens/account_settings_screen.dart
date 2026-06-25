import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/app/router/app_routes.dart';
import '../widgets/settings_widgets.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.accountSettings)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          SettingsSectionTitle(t.account),
          SettingsCard(
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.person_outline,
                  title: t.editProfile,
                  subtitle: t.editProfileDesc,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.email_outlined,
                  title: t.changeEmail,
                  subtitle: t.changeEmailDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.lock_outline,
                  title: t.changePassword,
                  subtitle: t.changePasswordDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.link_outlined,
                  title: t.connectedAccounts,
                  subtitle: t.connectedAccountsDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SettingsSectionTitle(t.activeSessions),
          SettingsCard(
            child: SettingsNavTile(
              icon: Icons.devices_outlined,
              title: t.activeSessions,
              subtitle: t.activeSessionsDesc,
              onTap: () => _showComingSoon(context, t),
            ),
          ),
          const SizedBox(height: 14),
          SettingsSectionTitle(t.downloadMyData),
          SettingsCard(
            child: SettingsNavTile(
              icon: Icons.download_outlined,
              title: t.downloadMyData,
              subtitle: t.downloadMyDataDesc,
              onTap: () => _showComingSoon(context, t),
            ),
          ),
          const SizedBox(height: 24),
          SettingsSectionTitle(t.dangerZone),
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.pause_circle_outline, color: cs.error),
                  title: Text(
                    t.deactivateAccount,
                    style: TextStyle(color: cs.error),
                  ),
                  subtitle: Text(t.deactivateAccountDesc),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showComingSoon(context, t),
                ),
                Divider(height: 1, color: cs.outline),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: cs.error),
                  title: Text(
                    t.deleteAccount,
                    style: TextStyle(color: cs.error),
                  ),
                  subtitle: Text(t.deleteAccountDesc),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showComingSoon(context, t),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.comingSoon),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
