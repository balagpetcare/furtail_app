import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/campaign_providers.dart';
import '../widgets/booking_tile.dart';

class CampaignHistoryScreen extends ConsumerWidget {
  const CampaignHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myCampaignBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign History')),
      body: bookingsAsync.when(
        data: (bookings) {
          final history = bookings.where((b) => b.isHistory).toList();
          if (history.isEmpty) {
            return const Center(child: Text('No past campaign bookings yet'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myCampaignBookingsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) => BookingTile(booking: history[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}
