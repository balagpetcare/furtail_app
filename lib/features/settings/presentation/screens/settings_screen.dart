import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/core/analytics/analytics_service.dart';
import 'package:furtail_app/core/crash_reporting/crash_reporting_service.dart';
import 'package:furtail_app/core/media/media_playback_controller.dart';
import 'package:furtail_app/core/localization/locale_controller.dart';
import 'package:furtail_app/features/auth/presentation/screens/login_screen.dart';

import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';
import 'account_settings_screen.dart';
import 'blocked_users_screen.dart';
import 'media_storage_settings_screen.dart';
import 'notification_preferences_screen.dart';
import 'privacy_settings_screen.dart';
import 'storage_cache_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final media = MediaPlaybackController.instance;

  @override
  void initState() {
    super.initState();
    media.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final localeAsync = ref.watch(localeControllerProvider);
    final localeCode = localeAsync.asData?.value.languageCode ?? 'en';
    final cs = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Account ──────────────────────────────────────────────────────
          SettingsSectionTitle(t.account),
          SettingsCard(
            child: SettingsNavTile(
              icon: Icons.manage_accounts_outlined,
              title: t.account,
              subtitle: t.accountDesc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Privacy & Safety ─────────────────────────────────────────────
          SettingsSectionTitle(t.privacySettings),
          SettingsCard(
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.lock_outline,
                  title: t.privacySettings,
                  subtitle: t.privacySettingsDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacySettingsScreen(),
                    ),
                  ),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.block,
                  title: t.blockedUsers,
                  subtitle: t.blockedUsersDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Notifications ────────────────────────────────────────────────
          SettingsSectionTitle(t.notificationPreferences),
          SettingsCard(
            child: SettingsNavTile(
              icon: Icons.notifications_outlined,
              title: t.notificationPreferences,
              subtitle: t.notificationPreferencesDesc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationPreferencesScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Media & Storage ──────────────────────────────────────────────
          SettingsSectionTitle(t.mediaAndStorage),
          SettingsCard(
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.high_quality_outlined,
                  title: t.mediaAndStorage,
                  subtitle: t.mediaAndStorageDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MediaStorageSettingsScreen(),
                    ),
                  ),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.storage_outlined,
                  title: t.storageAndCache,
                  subtitle: t.storageAndCacheDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StorageCacheScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Language ─────────────────────────────────────────────────────
          SettingsSectionTitle(t.language),
          SettingsCard(
            child: ListTile(
              leading: Icon(Icons.language_outlined, color: cs.primary),
              title: Text(t.language),
              subtitle: Text(localeCode == 'bn' ? t.bangla : t.english),
              trailing: DropdownButton<String>(
                value: localeCode,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: 'en', child: Text(t.english)),
                  DropdownMenuItem(value: 'bn', child: Text(t.bangla)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  ref.read(localeControllerProvider.notifier).setLocale(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Appearance ───────────────────────────────────────────────────
          SettingsSectionTitle(t.appearance),
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.light_mode_outlined, color: cs.primary),
                  title: Text(
                    t.themeLight,
                    style: AppTypography.menuTitle(context),
                  ),
                  subtitle: Text(
                    'Furtail uses a consistent light theme on all devices.',
                    style: AppTypography.drawerSubtitle(context),
                  ),
                ),
                Divider(height: 1, color: cs.outline),
                ValueListenableBuilder<bool>(
                  valueListenable: media.playOneByOneWifiOnly,
                  builder: (_, v, _) => SwitchListTile.adaptive(
                    value: v,
                    onChanged: (next) => media.playOneByOneWifiOnly.value = next,
                    title: Text(t.playVideosOneByOneWifiOnly),
                    subtitle: Text(t.playVideosOneByOneWifiOnlyDesc),
                  ),
                ),
                Divider(height: 1, color: cs.outline),
                ValueListenableBuilder<bool>(
                  valueListenable: media.isMuted,
                  builder: (_, v, _) => SwitchListTile.adaptive(
                    value: v,
                    onChanged: (next) => media.isMuted.value = next,
                    title: Text(t.muteAllVideos),
                    subtitle: Text(t.muteAllVideosDesc),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Help & Support ───────────────────────────────────────────────
          SettingsSectionTitle(t.helpAndSupport),
          SettingsCard(
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.help_outline,
                  title: t.faq,
                  subtitle: t.faqDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.support_agent_outlined,
                  title: t.contactSupport,
                  subtitle: t.contactSupportDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.bug_report_outlined,
                  title: t.reportBug,
                  subtitle: t.reportBugDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── About ────────────────────────────────────────────────────────
          SettingsSectionTitle(t.about),
          SettingsCard(
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.gavel_outlined,
                  title: t.communityGuidelines,
                  subtitle: t.communityGuidelinesDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.description_outlined,
                  title: t.termsOfService,
                  subtitle: t.termsOfServiceDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
                Divider(height: 1, color: cs.outline),
                SettingsNavTile(
                  icon: Icons.privacy_tip_outlined,
                  title: t.privacyPolicy,
                  subtitle: t.privacyPolicyDesc,
                  onTap: () => _showComingSoon(context, t),
                ),
                Divider(height: 1, color: cs.outline),
                ListTile(
                  leading: Icon(Icons.info_outline, color: cs.primary),
                  title: Text(t.appVersion),
                  trailing: const Text(
                    '10.0.0',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Logout ───────────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, t),
            icon: const Icon(Icons.logout),
            label: Text(t.logout),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
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

  Future<void> _confirmLogout(BuildContext context, AppLocalizations t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.logoutConfirmTitle),
        content: Text(t.logoutConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.logout),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref.read(settingsLogoutProvider)();
    await AnalyticsService.instance.clearUserId();
    await CrashReportingService.instance.clearUserId();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

}
