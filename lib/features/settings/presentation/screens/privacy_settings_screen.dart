import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

import '../../data/models/privacy_settings.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final prefsAsync = ref.watch(privacySettingsProvider);
    final cs = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.privacySettings)),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(t.refresh)),
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SettingsCard(
              child: Column(
                children: [
                  _switch(
                    context,
                    title: t.profileVisible,
                    subtitle: t.profileVisibleDesc,
                    value: prefs.profileVisibleToEveryone,
                    onChanged: (v) => _patch(ref, (p) => p.copyWith(profileVisibleToEveryone: v)),
                  ),
                  Divider(height: 1, color: cs.outline),
                  _switch(
                    context,
                    title: t.showOnlineStatus,
                    value: prefs.showOnlineStatus,
                    onChanged: (v) => _patch(ref, (p) => p.copyWith(showOnlineStatus: v)),
                  ),
                  Divider(height: 1, color: cs.outline),
                  _switch(
                    context,
                    title: t.messagesFollowersOnly,
                    value: prefs.allowMessagesFromFollowersOnly,
                    onChanged: (v) =>
                        _patch(ref, (p) => p.copyWith(allowMessagesFromFollowersOnly: v)),
                  ),
                  Divider(height: 1, color: cs.outline),
                  _switch(
                    context,
                    title: t.showActivityInFeed,
                    value: prefs.showActivityInFeed,
                    onChanged: (v) => _patch(ref, (p) => p.copyWith(showActivityInFeed: v)),
                  ),
                  Divider(height: 1, color: cs.outline),
                  _switch(
                    context,
                    title: t.allowTagging,
                    value: prefs.allowTagging,
                    onChanged: (v) => _patch(ref, (p) => p.copyWith(allowTagging: v)),
                  ),
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
    PrivacySettings Function(PrivacySettings) fn,
  ) {
    ref.read(privacySettingsProvider.notifier).apply(fn);
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
