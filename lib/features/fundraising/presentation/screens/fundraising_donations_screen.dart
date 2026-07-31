import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/fundraising_error_mapper.dart';
import '../providers/fundraising_providers.dart';
import '../utils/fundraising_formatters.dart';
import '../widgets/fundraising_status_views.dart';
import 'fundraising_common_scaffold.dart';

class FundraisingDonationsScreen extends ConsumerWidget {
  const FundraisingDonationsScreen({super.key, required this.campaignId});

  final int campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = fundraisingDonationsProvider(campaignId);
    final asyncValue = ref.watch(provider);

    Future<void> refresh() async {
      ref.invalidate(provider);
      await ref.read(provider.future);
    }

    return FundraisingCommonScaffold(
      title: 'Donations',
      showBack: true,
      showVerification: true,
      body: asyncValue.when(
        loading: () =>
            const FundraisingLoadingView(message: 'Loading donations…'),
        error: (error, _) {
          final safeError = mapFundraisingSafeError(error);
          return FundraisingErrorView(
            title: fundraisingErrorTitle(safeError),
            message: fundraisingErrorDescription(safeError),
            onRetry: refresh,
          );
        },
        data: (donations) {
          if (donations.isEmpty) {
            return const FundraisingEmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: 'No donations yet',
              message:
                  'New donations will appear here after successful payment confirmation.',
            );
          }

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: donations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final donation = donations[index];
                final colorScheme = Theme.of(context).colorScheme;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage:
                            (donation.donor.avatarUrl ?? '').trim().isNotEmpty
                            ? NetworkImage(donation.donor.avatarUrl!.trim())
                            : null,
                        child: (donation.donor.avatarUrl ?? '').trim().isEmpty
                            ? Icon(
                                Icons.person_outline_rounded,
                                color: colorScheme.onPrimaryContainer,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              donation.donor.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _timeAgo(donation.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatFundraisingMoney(context, donation.amount),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.isNegative || difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    final weeks = difference.inDays ~/ 7;
    if (weeks < 4) return '${weeks}w ago';
    final months = difference.inDays ~/ 30;
    if (months < 12) return '${months}mo ago';
    return '${difference.inDays ~/ 365}y ago';
  }
}
