import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/campaign_providers.dart';
import '../utils/campaign_health_utils.dart';
import '../widgets/vaccination_timeline_widget.dart';
import 'certificate_viewer_screen.dart';

class VaccinationTimelineScreen extends ConsumerWidget {
  final int? petId;
  final String? petName;

  const VaccinationTimelineScreen({super.key, this.petId, this.petName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(vaccinationRecordsProvider);
    final bookingsAsync = ref.watch(myCampaignBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(petName != null ? 'Timeline · $petName' : 'Vaccination Timeline'),
        backgroundColor: context.colorScheme.primary,
        foregroundColor: context.colorScheme.onPrimary,
      ),
      body: recordsAsync.when(
        data: (records) {
          return bookingsAsync.when(
            data: (bookings) {
              final events = buildVaccinationTimeline(
                records: records,
                bookings: bookings,
                petId: petId,
                petName: petName,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(vaccinationRecordsProvider);
                  ref.invalidate(myCampaignBookingsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      petId != null
                          ? 'Chronological health events for $petName from campaign bookings and vaccinations.'
                          : 'All campaign bookings and vaccinations linked to your phone.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    VaccinationTimelineWidget(
                      events: events,
                      onCertificateTap: (e) {
                        if (e.certificateToken == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CertificateViewerScreen(token: e.certificateToken!),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}
