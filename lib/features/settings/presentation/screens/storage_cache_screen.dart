import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/l10n/app_localizations.dart';

import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';

class StorageCacheScreen extends ConsumerWidget {
  const StorageCacheScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final usageAsync = ref.watch(storageUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.storageAndCache),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t.refresh,
            onPressed: () => ref.read(storageUsageProvider.notifier).refresh(),
          ),
        ],
      ),
      body: usageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(t.refresh)),
        data: (info) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SettingsSectionTitle(t.storageUsage),
            const SizedBox(height: 8),
            SettingsCard(
              child: Column(
                children: [
                  _row(t.cacheSize, formatBytes(info.cacheBytes)),
                  Divider(height: 1, color: context.colorScheme.outline),
                  _row(t.tempSize, formatBytes(info.tempBytes)),
                  Divider(height: 1, color: context.colorScheme.outline),
                  _row(t.totalSize, formatBytes(info.totalBytes), bold: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _confirmClear(context, ref, t),
              icon: const Icon(Icons.delete_outline),
              label: Text(t.clearCache),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.clearCache),
        content: Text(t.clearCacheConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.clearCache)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(storageUsageProvider.notifier).clearCache();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.cacheCleared)));
  }
}
