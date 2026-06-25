import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/utils/app_snackbar.dart' show showAppSnackBar;
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';
import '../../data/models/media_upload_settings.dart';

class MediaStorageSettingsScreen extends ConsumerWidget {
  const MediaStorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final cs = context.colorScheme;
    final settingsAsync = ref.watch(mediaUploadSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.mediaAndStorage)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text(t.somethingWentWrong)),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ── Upload Quality ────────────────────────────────────────────
            SettingsSectionTitle(t.uploadQuality),
            SettingsCard(
              child: Column(
                children: [
                  _qualityTile(
                    context: context,
                    ref: ref,
                    t: t,
                    label: t.uploadQualityDataSaver,
                    value: UploadQuality.dataSaver,
                    current: settings.uploadQuality,
                    icon: Icons.data_saver_on_outlined,
                  ),
                  Divider(height: 1, color: cs.outline),
                  _qualityTile(
                    context: context,
                    ref: ref,
                    t: t,
                    label: t.uploadQualityStandard,
                    value: UploadQuality.standard,
                    current: settings.uploadQuality,
                    icon: Icons.hd_outlined,
                  ),
                  Divider(height: 1, color: cs.outline),
                  _qualityTile(
                    context: context,
                    ref: ref,
                    t: t,
                    label: t.uploadQualityHigh,
                    value: UploadQuality.high,
                    current: settings.uploadQuality,
                    icon: Icons.high_quality_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Auto-play Videos ──────────────────────────────────────────
            SettingsSectionTitle(t.autoPlayVideos),
            SettingsCard(
              child: Column(
                children: [
                  _autoPlayTile(
                    context: context,
                    ref: ref,
                    t: t,
                    label: t.autoPlayAlways,
                    value: AutoPlaySetting.always,
                    current: settings.autoPlayVideos,
                    icon: Icons.play_circle_outline,
                  ),
                  Divider(height: 1, color: cs.outline),
                  _autoPlayTile(
                    context: context,
                    ref: ref,
                    t: t,
                    label: t.autoPlayWifiOnly,
                    value: AutoPlaySetting.wifiOnly,
                    current: settings.autoPlayVideos,
                    icon: Icons.wifi_outlined,
                  ),
                  Divider(height: 1, color: cs.outline),
                  _autoPlayTile(
                    context: context,
                    ref: ref,
                    t: t,
                    label: t.autoPlayNever,
                    value: AutoPlaySetting.never,
                    current: settings.autoPlayVideos,
                    icon: Icons.pause_circle_outline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Upload preferences ────────────────────────────────────────
            SettingsSectionTitle(t.uploadPreferences),
            SettingsCard(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: settings.compressImages,
                    onChanged: (v) => ref
                        .read(mediaUploadSettingsProvider.notifier)
                        .patch((s) => s.copyWith(compressImages: v)),
                    secondary: Icon(Icons.compress_outlined, color: cs.primary),
                    title: Text(t.compressImages),
                    subtitle: Text(t.compressImagesDesc),
                  ),
                  Divider(height: 1, color: cs.outline),
                  SwitchListTile.adaptive(
                    value: settings.compressVideos,
                    onChanged: (v) => ref
                        .read(mediaUploadSettingsProvider.notifier)
                        .patch((s) => s.copyWith(compressVideos: v)),
                    secondary: Icon(Icons.video_settings_outlined, color: cs.primary),
                    title: Text(t.compressVideos),
                    subtitle: Text(t.compressVideosDesc),
                  ),
                  Divider(height: 1, color: cs.outline),
                  SwitchListTile.adaptive(
                    value: settings.saveUploadedMedia,
                    onChanged: (v) => ref
                        .read(mediaUploadSettingsProvider.notifier)
                        .patch((s) => s.copyWith(saveUploadedMedia: v)),
                    secondary: Icon(Icons.save_outlined, color: cs.primary),
                    title: Text(t.saveUploadedMedia),
                    subtitle: Text(t.saveUploadedMediaDesc),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Cache ─────────────────────────────────────────────────────
            SettingsSectionTitle(t.storageAndCache),
            SettingsCard(
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: cs.primary),
                title: Text(t.clearMediaCache),
                subtitle: Text(t.clearMediaCacheDesc),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _confirmClearCache(context, ref, t),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _qualityTile({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations t,
    required String label,
    required UploadQuality value,
    required UploadQuality current,
    required IconData icon,
  }) {
    final selected = current == value;
    final cs = context.colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.radio_button_checked, color: cs.primary)
          : const Icon(Icons.radio_button_off),
      onTap: () => ref
          .read(mediaUploadSettingsProvider.notifier)
          .patch((s) => s.copyWith(uploadQuality: value)),
    );
  }

  Widget _autoPlayTile({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations t,
    required String label,
    required AutoPlaySetting value,
    required AutoPlaySetting current,
    required IconData icon,
  }) {
    final selected = current == value;
    final cs = context.colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.radio_button_checked, color: cs.primary)
          : const Icon(Icons.radio_button_off),
      onTap: () => ref
          .read(mediaUploadSettingsProvider.notifier)
          .patch((s) => s.copyWith(autoPlayVideos: value)),
    );
  }

  Future<void> _confirmClearCache(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.clearMediaCache),
        content: Text(t.clearCacheConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.clearCache)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await DefaultCacheManager().emptyCache();
      if (!context.mounted) return;
      showAppSnackBar(context, t.mediaCacheCleared);
    } catch (_) {
      if (!context.mounted) return;
      showAppSnackBar(context, t.somethingWentWrong);
    }
  }
}
