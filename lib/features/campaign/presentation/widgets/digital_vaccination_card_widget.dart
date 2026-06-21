import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/campaign_models.dart';

/// Wallet-style digital vaccination card for one dose / certificate.
class DigitalVaccinationCardWidget extends StatelessWidget {
  final VaccinationRecord record;
  final String? photoUrl;
  final VoidCallback? onTap;

  const DigitalVaccinationCardWidget({
    super.key,
    required this.record,
    this.photoUrl,
    this.onTap,
  });

  static const _gradient = LinearGradient(
    colors: [Color(0xFF0B5C5C), Color(0xFF1E60AA), Color(0xFF2E86C1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final administered = record.administeredAt != null
        ? DateFormat('d MMM yyyy').format(record.administeredAt!)
        : '—';
    final validUntil = record.nextDueDate != null
        ? DateFormat('d MMM yyyy').format(record.nextDueDate!)
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(gradient: _gradient),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PetAvatar(name: record.petName, photoUrl: photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.petName,
                          style: context.appText.headlineMedium!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          record.animalType ?? 'Cat',
                          style: context.appText.bodyMedium!.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_rounded, color: Color(0xFFC8A951), size: 32),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'DIGITAL VACCINATION CARD',
                style: context.appText.labelMedium!.copyWith(
                  color: const Color(0xFFC8A951),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _row(context, 'Vaccine', record.vaccineType),
              _row(context, 'Given', administered),
              _row(context, 'Valid until', validUntil),
              _row(context, 'Campaign', record.campaignName ?? 'Furtail 2026'),
              if (record.certificateToken != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.certificateToken!,
                    style: context.appText.labelMedium!.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: context.appText.bodyMedium!.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.appText.labelLarge!.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _PetAvatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: context.appText.headlineMedium!.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
