import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fundraising_providers.dart';
import '../widgets/fundraising_card.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_common_scaffold.dart';
import 'fundraising_details_screen.dart';

class FundraisingFeedScreen extends ConsumerWidget {
  const FundraisingFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(fundraisingFeedProvider);
    final q = ref.watch(fundraisingFeedQueryProvider);

    return FundraisingCommonScaffold(
      title: 'All Donations',
      showBack: true,
      showWithdrawHub: true,
      showFilters: true,
      showVerification: true,
      showCreate: true,
      onOpenFilters: () => _openFilters(context, ref),
      body: asyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.volunteer_activism,
                      size: 48,
                      color: Colors.black54,
                    ),
                    const SizedBox(height: 12),
                    const Text('No fundraising campaigns found.'),
                    const SizedBox(height: 12),
                    Text(
                      _querySummary(q),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(fundraisingFeedQueryProvider.notifier)
                          .clearAll(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Clear filters'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = list[index];
              return FundraisingCard(
                campaign: c,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FundraisingDetailsScreen(campaignId: c.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _querySummary(FundraisingFeedQuery q) {
    final parts = <String>[];
    parts.add('Sort: ${q.sort.name}');
    if (q.verified != null) {
      parts.add(q.verified == true ? 'Verified only' : 'Non-verified only');
    }
    if ((q.category ?? '').isNotEmpty) parts.add('Category: ${q.category}');
    if ((q.location ?? '').isNotEmpty) parts.add('Location: ${q.location}');
    return parts.isEmpty ? '' : parts.join(' • ');
  }

  void _openFilters(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(fundraisingFeedQueryProvider.notifier);
    final q = ref.read(fundraisingFeedQueryProvider);
    final locationCtrl = TextEditingController(text: q.location ?? '');
    String? category = q.category;
    bool? verified = q.verified;
    FundraisingSort sort = q.sort;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          notifier.clearAll();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<FundraisingSort>(
                    initialValue: sort,
                    decoration: const InputDecoration(
                      labelText: 'Sort',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: FundraisingSort.endingSoon,
                        child: Text('Ending soon'),
                      ),
                      DropdownMenuItem(
                        value: FundraisingSort.newCampaigns,
                        child: Text('New campaigns'),
                      ),
                      DropdownMenuItem(
                        value: FundraisingSort.topDonated,
                        child: Text('Top donated'),
                      ),
                    ],
                    onChanged: (v) => setState(() => sort = v ?? sort),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool?>(
                    initialValue: verified,
                    decoration: const InputDecoration(
                      labelText: 'Verification',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                        value: true,
                        child: Text('Verified only'),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text('Non-verified only'),
                      ),
                    ],
                    onChanged: (v) => setState(() => verified = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                        value: 'Treatment',
                        child: Text('Treatment'),
                      ),
                      DropdownMenuItem(value: 'Food', child: Text('Food')),
                      DropdownMenuItem(
                        value: 'Shelter',
                        child: Text('Shelter'),
                      ),
                      DropdownMenuItem(
                        value: 'Vaccination',
                        child: Text('Vaccination'),
                      ),
                      DropdownMenuItem(value: 'Rescue', child: Text('Rescue')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => category = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location / Area',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      notifier.setSort(sort);
                      notifier.setVerified(verified);
                      notifier.setCategory(category);
                      final loc = locationCtrl.text.trim();
                      notifier.setLocation(loc.isEmpty ? null : loc);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
