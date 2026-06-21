import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_common_scaffold.dart';

class FundraisingDonationsScreen extends ConsumerWidget {
  final int campaignId;
  const FundraisingDonationsScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(fundraisingDonationsProvider(campaignId));

    return FundraisingCommonScaffold(
      title: 'All Donations',
      showBack: true,
      showFilters: false,
      showVerification: true,
      showCreate: false,
      body: asyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No donations yet'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = list[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      (d.donor.avatarUrl != null &&
                          d.donor.avatarUrl!.isNotEmpty)
                      ? NetworkImage(d.donor.avatarUrl!)
                      : null,
                  child:
                      (d.donor.avatarUrl == null || d.donor.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                title: Text(d.donor.name),
                subtitle: Text('৳ ${d.amount}  •  ${_timeAgo(d.createdAt)}'),
              );
            },
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  }
}
