import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fundraising_providers.dart';
import '../widgets/action_buttons.dart';
import '../widgets/donate_now_bar.dart';
import '../widgets/progress_bar.dart';
import '../widgets/updates_section.dart';

class FundraisingDetailsPage extends ConsumerWidget {
  final int campaignId;

  const FundraisingDetailsPage({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCampaign = ref.watch(fundraisingCampaignProvider(campaignId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.reply),
            onPressed: () {
              // Share action
            },
          ),
          PopupMenuButton<String>(
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit Post')),
              PopupMenuItem(value: 'update', child: Text('Post Update')),
              PopupMenuItem(value: 'delete', child: Text('Delete Post')),
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
            onSelected: (v) {
              // Hook to your existing flows
            },
          ),
        ],
      ),
      body: asyncCampaign.when(
        data: (c) => _Body(campaignId: campaignId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
      ),
      bottomNavigationBar: DonateNowBar(
        onDonate: () async {
          // Hook: show a bottom sheet amount picker then call api.donate(...)
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final int campaignId;

  const _Body({required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(fundraisingCampaignProvider(campaignId)).requireValue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Media carousel placeholder (replace with your existing media viewer)
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.image_outlined, size: 48)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Text(
          c.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(c.caption ?? '', style: Theme.of(context).textTheme.bodyMedium),

        const SizedBox(height: 14),
        FundraisingProgressBar(raised: c.raisedAmount, target: c.targetAmount),

        const SizedBox(height: 16),
        Row(
          children: [
            _MiniStat(
              icon: Icons.favorite_border,
              text: '${c.likeCount ?? 0} Likes',
            ),
            const SizedBox(width: 18),
            _MiniStat(
              icon: Icons.chat_bubble_outline,
              text: '${c.commentCount ?? 0} Comments',
            ),
            const SizedBox(width: 18),
            _MiniStat(icon: Icons.share, text: '${c.shareCount ?? 0} Shares'),
          ],
        ),

        const SizedBox(height: 18),
        const Divider(height: 1),

        const SizedBox(height: 18),
        FundraisingActionButtons(
          onAdopt: () {},
          onVolunteer: () {},
          onShare: () {},
        ),

        const SizedBox(height: 22),
        const Divider(height: 1),

        const SizedBox(height: 18),
        FundraisingUpdatesSection(campaignId: campaignId),

        const SizedBox(height: 18),
        const Divider(height: 1),

        const SizedBox(height: 18),
        // Comments: hook to your existing posts/comments module
        Text('Comments', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Text(
          'Hook this section to your existing Posts comments API so it matches the screenshot (Reply thread + owner reply).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(text)],
    );
  }
}
