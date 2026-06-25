import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/campaign_booking_location_providers.dart';
import '../providers/campaign_providers.dart';
import '../widgets/campaign_state_views.dart';
import 'campaign_hub_screen.dart';
import 'qr_viewer_screen.dart';

class CampaignSuccessPage extends ConsumerWidget {
  final String bookingRef;
  final String? verificationCode;
  final String slug;

  const CampaignSuccessPage({
    super.key,
    required this.bookingRef,
    this.verificationCode,
    required this.slug,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = campaignHorizontalPadding(context);
    final ticketsAsync = ref.watch(bookingTicketsProvider(bookingRef));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking confirmed')),
      body: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Your vaccination is booked!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Campaign center will be assigned for your area. SMS confirmation includes ticket links.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking ID', style: Theme.of(context).textTheme.labelLarge),
                    SelectableText(
                      bookingRef,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (verificationCode != null && verificationCode!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Verification code', style: Theme.of(context).textTheme.labelLarge),
                      SelectableText(verificationCode!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Per-cat tickets', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: ticketsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text('Tickets will arrive via SMS shortly.'),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const Text('Tickets are being generated…');
                  }
                  return ListView.separated(
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = tickets[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(t.petName),
                          subtitle: Text(t.bookingArea ?? 'Area confirmed'),
                          trailing: IconButton(
                            icon: const Icon(Icons.qr_code_2),
                            onPressed: () {
                              final payload = t.qrImageBase64 != null && t.qrImageBase64!.startsWith('data:')
                                  ? t.ticketUrl
                                  : t.ticketToken;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QrViewerScreen(
                                    title: t.petName,
                                    payload: payload,
                                    subtitle: bookingRef,
                                    qrImageBase64: _extractBase64(t.qrImageBase64),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(campaignRepositoryProvider).importRecords();
                } catch (_) {}
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const CampaignHubScreen()),
                  (r) => r.isFirst,
                );
              },
              child: const Text('View in My Campaigns'),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractBase64(String? dataUrl) {
    if (dataUrl == null || !dataUrl.contains(',')) return null;
    return dataUrl.split(',').last;
  }
}
