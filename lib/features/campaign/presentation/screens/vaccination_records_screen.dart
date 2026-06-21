import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/campaign_providers.dart';
import '../widgets/vaccination_record_tile.dart';
import 'certificate_viewer_screen.dart';

class VaccinationRecordsScreen extends ConsumerWidget {
  const VaccinationRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(vaccinationRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vaccination Records')),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('No vaccination records yet'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vaccinationRecordsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = records[i];
                return VaccinationRecordTile(
                  record: r,
                  onCertificateTap: r.certificateToken == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CertificateViewerScreen(
                                token: r.certificateToken!,
                              ),
                            ),
                          );
                        },
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
