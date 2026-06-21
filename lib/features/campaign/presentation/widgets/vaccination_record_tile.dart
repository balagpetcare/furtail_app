import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/campaign_models.dart';

class VaccinationRecordTile extends StatelessWidget {
  final VaccinationRecord record;
  final VoidCallback? onCertificateTap;

  const VaccinationRecordTile({
    super.key,
    required this.record,
    this.onCertificateTap,
  });

  @override
  Widget build(BuildContext context) {
    final administered = record.administeredAt != null
        ? DateFormat('d MMM yyyy').format(record.administeredAt!)
        : '—';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            record.source == 'campaign' ? Icons.campaign : Icons.pets,
          ),
        ),
        title: Text('${record.petName} · ${record.vaccineType}'),
        subtitle: Text(
          '$administered\n${record.campaignName ?? ''}${record.location != null ? ' · ${record.location}' : ''}',
        ),
        isThreeLine: true,
        trailing: record.certificateToken != null
            ? IconButton(
                icon: const Icon(Icons.verified_outlined),
                onPressed: onCertificateTap,
              )
            : null,
      ),
    );
  }
}
