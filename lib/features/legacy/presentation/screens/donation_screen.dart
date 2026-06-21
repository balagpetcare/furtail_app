import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_card.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_details_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_create_screen.dart';

enum DonationSort {
  newest,
  endingSoon,
  progressLow,
  progressHigh,
}

class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen> {
  DonationSort _sort = DonationSort.endingSoon;

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(fundraisingFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation'),
        actions: [
          PopupMenuButton<DonationSort>(
            initialValue: _sort,
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: DonationSort.endingSoon, child: Text('Ending soon')),
              PopupMenuItem(value: DonationSort.newest, child: Text('Newest')),
              PopupMenuItem(value: DonationSort.progressHigh, child: Text('Highest progress')),
              PopupMenuItem(value: DonationSort.progressLow, child: Text('Lowest progress')),
            ],
          ),
          IconButton(
            tooltip: 'Start Fund Raising',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const FundraisingCreateScreen()),
              );
              if (created == true) {
                ref.invalidate(fundraisingFeedProvider);
              }
            },
          ),
        ],
      ),
      body: asyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No donation campaigns found.'));
          }

          final sorted = [...list];
          sorted.sort((a, b) {
            double prog(dynamic c) {
              final raised = (c.raisedAmount ?? 0).toDouble();
              final target = (c.targetAmount ?? 0).toDouble();
              if (target <= 0) return 0;
              return (raised / target).clamp(0, 1);
            }

            switch (_sort) {
              case DonationSort.newest:
                return b.createdAt.compareTo(a.createdAt);
              case DonationSort.endingSoon:
                final ad = a.deadline ?? DateTime(9999);
                final bd = b.deadline ?? DateTime(9999);
                return ad.compareTo(bd);
              case DonationSort.progressHigh:
                return prog(b).compareTo(prog(a));
              case DonationSort.progressLow:
                return prog(a).compareTo(prog(b));
            }
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = sorted[index];
              return FundraisingCard(
                campaign: c,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => FundraisingDetailsScreen(campaignId: c.id)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
