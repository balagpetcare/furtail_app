import 'package:flutter/material.dart';

import 'package:bpa_app/core/theme/typography.dart';
import '../../data/models/campaign_models.dart';
import '../utils/campaign_format_utils.dart';

class BookingTile extends StatelessWidget {
  final CampaignBooking booking;
  final VoidCallback? onQrTap;

  const BookingTile({super.key, required this.booking, this.onQrTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.bookingRef,
                    style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: 6),
            if (booking.campaignName != null)
              Text(booking.campaignName!, style: const TextStyle(color: Colors.black54)),
            Text(
              formatCampaignDateTime(
                booking.bookingDate,
                booking.slotStart,
                booking.slotEnd,
              ),
            ),
            Text(
              '${booking.locationName ?? booking.coverageZoneName ?? booking.bookingArea ?? 'Venue pending'}'
              '${booking.locationAddress != null ? ' · ${booking.locationAddress}' : ''}',
            ),
            if (booking.pets.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: booking.pets
                    .map(
                      (p) => Chip(
                        label: Text('${p.name} · ${p.vaccinationStatus}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (onQrTap != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onQrTap,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Show QR'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.blue;
    if (status == 'COMPLETED') color = Colors.green;
    if (status == 'CANCELLED' || status == 'NO_SHOW') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: context.appText.labelMedium!.copyWith(color: color),
      ),
    );
  }
}
