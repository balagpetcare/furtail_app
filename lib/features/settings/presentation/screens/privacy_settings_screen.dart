import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';

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
        error: (e, s) => Center(child: Text(t.somethingWentWrong)),
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ── Visibility & Activity ──────────────────────────────────────
            SettingsSectionTitle(t.profileVisible),
            SettingsCard(
              child: Column(
                children: [
                  _switch(
                    context,
                    title: t.profileVisible,
                    subtitle: t.profileVisibleDesc,
                    value: prefs.profileVisibleToEveryone,
                    onChanged: (v) =>
                        _patch(ref, (p) => p.copyWith(profileVisibleToEveryone: v)),
                  ),
                  Divider(height: 1, color: cs.outline),
                  _switch(
                    context,
                    title: t.showOnlineStatus,
                    value: prefs.showOnlineStatus,
                    onChanged: (v) =>
                        _patch(ref, (p) => p.copyWith(showOnlineStatus: v)),
                  ),
                  Divider(height: 1, color: cs.outline),
                  _switch(
                    context,
                    title: t.showActivityInFeed,
                    value: prefs.showActivityInFeed,
                    onChanged: (v) =>
                        _patch(ref, (p) => p.copyWith(showActivityInFeed: v)),
                  ),
                  Divider(height: 1, color: cs.outline),
                  _switch(
                    context,
                    title: t.allowTagging,
                    value: prefs.allowTagging,
                    onChanged: (v) =>
                        _patch(ref, (p) => p.copyWith(allowTagging: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Interactions ───────────────────────────────────────────────
            SettingsSectionTitle(t.interactions),
            SettingsCard(
              child: Column(
                children: [
                  _switch(
                    context,
                    title: t.messagesFollowersOnly,
                    value: prefs.allowMessagesFromFollowersOnly,
                    onChanged: (v) =>
                        _patch(ref, (p) => p.copyWith(allowMessagesFromFollowersOnly: v)),
                  ),
                  Divider(height: 1, color: cs.outline),
                  // Who can comment — segmented radio list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.whoCanComment,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.whoCanCommentDesc,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _commentPermissionRow(context, ref, prefs, CommentPermission.everyone, t.everyone),
                        _commentPermissionRow(context, ref, prefs, CommentPermission.followersOnly, t.followersOnly),
                        _commentPermissionRow(context, ref, prefs, CommentPermission.noOne, t.noOne),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Safety & Reporting ─────────────────────────────────────────
            SettingsSectionTitle(t.safety),
            SettingsCard(
              child: Column(
                children: [
                  SettingsNavTile(
                    icon: Icons.flag_outlined,
                    title: t.reportAProblem,
                    subtitle: t.reportAProblemDesc,
                    onTap: () => ReportBottomSheet.show(
                      context,
                      targetType: ReportTargetType.user,
                      targetId: 0,
                    ),
                  ),
                  Divider(height: 1, color: cs.outline),
                  SettingsNavTile(
                    icon: Icons.gavel_outlined,
                    title: t.communityGuidelinesShort,
                    subtitle: t.communityGuidelinesDesc,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.comingSoon)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _commentPermissionRow(
    BuildContext context,
    WidgetRef ref,
    PrivacySettings prefs,
    CommentPermission value,
    String label,
  ) {
    return RadioListTile<CommentPermission>(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      groupValue: prefs.whoCanComment,
      title: Text(label),
      onChanged: (v) {
        if (v != null) _patch(ref, (p) => p.copyWith(whoCanComment: v));
      },
    );
  }

  void _patch(WidgetRef ref, PrivacySettings Function(PrivacySettings) fn) {
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
