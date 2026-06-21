import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fundraising_providers.dart';

class FundraisingUpdatesSection extends ConsumerWidget {
  final int campaignId;

  const FundraisingUpdatesSection({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUpdates = ref.watch(fundraisingUpdatesProvider(campaignId));
    return asyncUpdates.when(
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Updates', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...list.map(
            (u) => _UpdateCard(
              authorName: 'Campaign Owner',
              timeText: _time(u.createdAt),
              text: u.text,
              hasAttachment: u.attachment != null,
            ),
          ),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text('Failed to load updates: $e'),
      ),
    );
  }

  String _time(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _UpdateCard extends StatelessWidget {
  final String authorName;
  final String timeText;
  final String text;
  final bool hasAttachment;

  const _UpdateCard({
    required this.authorName,
    required this.timeText,
    required this.text,
    required this.hasAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(timeText, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(text),
                if (hasAttachment) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          // Hook: open attachment URL using url_launcher
                        },
                        child: const Text('Download PDF'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
