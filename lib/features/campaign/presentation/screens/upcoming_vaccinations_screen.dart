import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/campaign_providers.dart';
import '../utils/campaign_format_utils.dart';
import 'qr_viewer_screen.dart';

class UpcomingVaccinationsScreen extends ConsumerWidget {
  const UpcomingVaccinationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingVaccinationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Vaccinations')),
      body: upcomingAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No upcoming vaccinations scheduled'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(upcomingVaccinationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final u = items[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.event_available),
                    ),
                    title: Text(u.campaignName),
                    subtitle: Text(
                      '${formatCampaignDateTime(u.bookingDate, u.slotStart, u.slotEnd)}\n'
                      '${u.locationName}${u.pets.isNotEmpty ? ' · ${u.pets.map((p) => p.name).join(', ')}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: u.qrToken != null
                        ? IconButton(
                            icon: const Icon(Icons.qr_code_2_rounded),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => QrViewerScreen(
                                    title: u.bookingRef,
                                    payload: u.qrToken!,
                                    subtitle: formatCampaignDate(u.bookingDate),
                                  ),
                                ),
                              );
                            },
                          )
                        : null,
                  ),
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
}
