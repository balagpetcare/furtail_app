import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

import '../../data/models/blocked_user.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_widgets.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final listAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.blockedUsers),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_off_outlined),
            tooltip: t.blockUser,
            onPressed: () => _showBlockDialog(context, ref, t),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(t.refresh)),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 48, color: context.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(t.noBlockedUsers, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      t.noBlockedUsersDesc,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              return SettingsCard(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(user.displayName),
                  subtitle: Text('ID ${user.userId}'),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(blockedUsersProvider.notifier).unblock(user.userId),
                    child: Text(t.unblock),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showBlockDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final idController = TextEditingController();
    final nameController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.blockUser),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.blockUserHint),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.userId),
            ),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: t.displayName),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;
    final id = int.tryParse(idController.text.trim());
    if (id == null || id <= 0) return;

    await ref.read(blockedUsersProvider.notifier).block(
          BlockedUser(
            userId: id,
            displayName: nameController.text.trim().isEmpty
                ? 'User $id'
                : nameController.text.trim(),
            blockedAt: DateTime.now(),
          ),
        );
  }
}
