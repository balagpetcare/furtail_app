import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/l10n/app_localizations.dart';

import '../../data/models/notification_preferences.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final cs = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.notificationPreferences)),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(t.refresh)),
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SettingsCard(
              child: _switch(
                context,
                title: t.pushNotifications,
                subtitle: t.pushNotificationsDesc,
                value: prefs.pushEnabled,
                onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(pushEnabled: v)),
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              child: Column(
                children: [
                  _switch(context, title: t.campaignReminders, value: prefs.campaignReminders,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(campaignReminders: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(context, title: t.vaccineReminders, value: prefs.vaccineReminders,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(vaccineReminders: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(context, title: t.donationUpdates, value: prefs.donationUpdates,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(donationUpdates: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(context, title: t.communityActivity, value: prefs.communityActivity,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(communityActivity: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(context, title: t.commentsNotif, value: prefs.comments,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(comments: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(context, title: t.likesNotif, value: prefs.likes,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(likes: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(context, title: t.followsNotif, value: prefs.follows,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(follows: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(context, title: t.announcementsNotif, value: prefs.announcements,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(announcements: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(
                    context,
                    title: t.emergencyNotif,
                    subtitle: t.emergencyNotifDesc,
                    value: prefs.emergency,
                    onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(emergency: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              child: Column(
                children: [
                  _switch(context, title: t.allowEmailNotif, value: prefs.allowEmail,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(allowEmail: v))),
                  Divider(height: 1, color: cs.outline),
                  _switch(context, title: t.allowSmsNotif, value: prefs.allowSms,
                      onChanged: (v) => _patch(ref, prefs, (p) => p.copyWith(allowSms: v))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _patch(
    WidgetRef ref,
    NotificationPreferences prefs,
    NotificationPreferences Function(NotificationPreferences) fn,
  ) {
    ref.read(notificationPreferencesProvider.notifier).apply(fn);
  }

  Widget _switch(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
    );
  }
}
