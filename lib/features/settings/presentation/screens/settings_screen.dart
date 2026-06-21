import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/app_typography.dart';
import 'package:bpa_app/l10n/app_localizations.dart';
import 'package:bpa_app/core/analytics/analytics_service.dart';
import 'package:bpa_app/core/crash_reporting/crash_reporting_service.dart';
import 'package:bpa_app/core/media/media_playback_controller.dart';
import 'package:bpa_app/core/localization/locale_controller.dart';
import 'package:bpa_app/features/auth/presentation/screens/login_screen.dart';

import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';
import 'blocked_users_screen.dart';
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
          SettingsSectionTitle(t.appearance),
          SettingsCard(
            child: ListTile(
              leading: Icon(Icons.light_mode_outlined, color: cs.primary),
              title: Text(
                t.themeLight,
                style: AppTypography.menuTitle(context),
              ),
              subtitle: Text(
                'BPA uses a consistent light theme on all devices. '
                'Screen brightness can still be adjusted in Android settings.',
                style: AppTypography.drawerSubtitle(context),
              ),
            ),
          ),
          const SizedBox(height: 14),

          SettingsSectionTitle(t.language),
          SettingsCard(
            child: ListTile(
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

          SettingsSectionTitle(t.mediaPlayback),
          SettingsCard(
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: media.playOneByOneWifiOnly,
                  builder: (_, v, __) {
                    return SwitchListTile.adaptive(
                      value: v,
                      onChanged: (next) =>
                          media.playOneByOneWifiOnly.value = next,
                      title: Text(t.playVideosOneByOneWifiOnly),
                      subtitle: Text(t.playVideosOneByOneWifiOnlyDesc),
                    );
                  },
                ),
                Divider(height: 1, color: cs.outline),
                ValueListenableBuilder<bool>(
                  valueListenable: media.isMuted,
                  builder: (_, v, __) {
                    return SwitchListTile.adaptive(
                      value: v,
                      onChanged: (next) => media.isMuted.value = next,
                      title: Text(t.muteAllVideos),
                      subtitle: Text(t.muteAllVideosDesc),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SettingsSectionTitle(t.settings),
          SettingsCard(
            child: Column(
              children: [
                SettingsNavTile(
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
                Divider(height: 1, color: cs.outline),
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
          const SizedBox(height: 24),

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
