import 'package:flutter/material.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:intl/intl.dart';

import '../utils/campaign_health_utils.dart';

class VaccinationTimelineWidget extends StatelessWidget {
  final List<VaccinationTimelineEvent> events;
  final void Function(VaccinationTimelineEvent event)? onCertificateTap;

  const VaccinationTimelineWidget({
    super.key,
    required this.events,
    this.onCertificateTap,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No vaccination timeline events yet. Book a campaign appointment or complete a vaccination.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final e = events[i];
        final isLast = i == events.length - 1;
        return _TimelineRow(
          event: e,
          showLine: !isLast,
          onCertificateTap: e.certificateToken != null ? () => onCertificateTap?.call(e) : null,
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final VaccinationTimelineEvent event;
  final bool showLine;
  final VoidCallback? onCertificateTap;

  const _TimelineRow({
    required this.event,
    required this.showLine,
    this.onCertificateTap,
  });

  IconData get _icon {
    switch (event.type) {
      case VaccinationTimelineEventType.vaccination:
        return Icons.vaccines_rounded;
      case VaccinationTimelineEventType.booking:
        return Icons.event_available_rounded;
      case VaccinationTimelineEventType.checkIn:
        return Icons.qr_code_scanner_rounded;
      case VaccinationTimelineEventType.completed:
        return Icons.check_circle_outline_rounded;
    }
  }

  Color _eventColor(BuildContext context) {
    switch (event.type) {
      case VaccinationTimelineEventType.vaccination:
        return Colors.teal;
      case VaccinationTimelineEventType.booking:
        return context.colorScheme.primary;
      case VaccinationTimelineEventType.checkIn:
        return Colors.orange;
      case VaccinationTimelineEventType.completed:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(context);
    final dateStr =
        event.at != null ? DateFormat('d MMM yyyy · HH:mm').format(event.at!) : '—';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(_icon, size: 18, color: color),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.subtitle,
                        style: context.appText.bodyMedium!.copyWith(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${event.petName} · $dateStr',
                        style: context.appText.bodySmall!.copyWith(color: Colors.grey.shade600),
                      ),
                      if (onCertificateTap != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: onCertificateTap,
                          icon: const Icon(Icons.verified_outlined, size: 18),
                          label: const Text('View certificate'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
