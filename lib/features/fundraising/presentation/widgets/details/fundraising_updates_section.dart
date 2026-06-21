import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:bpa_app/core/constants/app_colors.dart';
import 'package:bpa_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:bpa_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:bpa_app/features/fundraising/presentation/screens/fundraising_update_editor_screen.dart';
import 'package:bpa_app/features/fundraising/presentation/utils/fundraising_time_ago.dart';

import 'fundraising_details_dialogs.dart';
import 'read_more_text.dart';

class FundraisingUpdatesHeader extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onAdd;
  const FundraisingUpdatesHeader({super.key, required this.isOwner, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Updates',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (isOwner)
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
      ],
    );
  }
}

class FundraisingUpdatesList extends ConsumerWidget {
  final int campaignId;
  final bool isOwner;
  const FundraisingUpdatesList({super.key, required this.campaignId, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(fundraisingUpdatesProvider(campaignId));

    return asyncValue.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(e.toString()),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 6),
            child: Text('No updates yet'),
          );
        }
        return Column(
          children: list
              .map(
                (u) => FundraisingUpdateCard(
                  update: u,
                  campaignId: campaignId,
                  isOwner: isOwner,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class FundraisingUpdateCard extends ConsumerWidget {
  final int campaignId;
  final bool isOwner;
  final FundraisingUpdateItem update;

  const FundraisingUpdateCard({
    super.key,
    required this.update,
    required this.campaignId,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage:
                    (update.author.avatarUrl != null && update.author.avatarUrl!.isNotEmpty)
                        ? NetworkImage(update.author.avatarUrl!)
                        : null,
                child: (update.author.avatarUrl == null || update.author.avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 14)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      update.author.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      fundraisingTimeAgo(update.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    final repo = ref.read(fundraisingRepositoryProvider);
                    if (v == 'edit') {
                      final ok = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => FundraisingUpdateEditorScreen(
                            campaignId: campaignId,
                            existing: update,
                          ),
                        ),
                      );
                      if (ok == true) {
                        ref.invalidate(fundraisingUpdatesProvider(campaignId));
                      }
                    }
                    if (v == 'delete') {
                      final confirmed = await confirmDialog(
                        context,
                        title: 'Delete update?',
                        message: 'This update will be removed.',
                        okText: 'Delete',
                      );
                      if (confirmed != true) return;
                      await repo.deleteUpdate(updateId: update.id);
                      ref.invalidate(fundraisingUpdatesProvider(campaignId));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if ((update.caption ?? '').trim().isNotEmpty)
            ReadMoreText(text: update.caption!.trim(), maxLines: 3),
          if (update.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: update.media.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = update.media[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: m.url,
                      width: 120,
                      height: 92,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.black12, width: 120, height: 92),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.black12,
                        width: 120,
                        height: 92,
                        child: const Center(child: Icon(Icons.broken_image_outlined, size: 18)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
