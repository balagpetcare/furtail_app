import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/campaign_models.dart';
import '../providers/campaign_providers.dart';
import '../utils/campaign_format_utils.dart';
import '../widgets/booking_tile.dart';
import 'qr_viewer_screen.dart';

class MyCampaignsScreen extends ConsumerWidget {
  const MyCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myCampaignBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Campaigns')),
      body: bookingsAsync.when(
        data: (bookings) {
          final active = bookings.where((b) => !b.isHistory).toList();
          if (active.isEmpty) {
            return const Center(child: Text('No active campaign bookings'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myCampaignBookingsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: active.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = active[i];
                return BookingTile(
                  booking: b,
                  onQrTap: b.qrToken == null
                      ? null
                      : () => _openQr(context, b),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  void _openQr(BuildContext context, CampaignBooking booking) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrViewerScreen(
          title: booking.bookingRef,
          payload: booking.qrToken!,
          subtitle: formatCampaignDateTime(
            booking.bookingDate,
            booking.slotStart,
            booking.slotEnd,
          ),
        ),
      ),
    );
  }
}
