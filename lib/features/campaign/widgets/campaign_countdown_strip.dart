import 'package:flutter/material.dart';

import '../data/models/campaign_countdown.dart';

/// Countdown + slots strip for homepage campaign banner.
class CampaignCountdownStrip extends StatelessWidget {
  final CampaignCountdownSnapshot? countdown;
  final int? remainingSlots;
  final bool showSlots;

  const CampaignCountdownStrip({
    super.key,
    this.countdown,
    this.remainingSlots,
    this.showSlots = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    if (countdown != null && countdown!.countdownEnabled && !countdown!.isExpired) {
      chips.add(_Chip(
        icon: Icons.timer_outlined,
        label: '${countdown!.daysLeft}d ${countdown!.hoursLeft}h left',
        color: cs.primaryContainer,
        fg: cs.onPrimaryContainer,
      ));
    }

    if (showSlots && remainingSlots != null && remainingSlots! > 0) {
      chips.add(_Chip(
        icon: Icons.event_seat_outlined,
        label: remainingSlots! <= 5 ? 'Almost full' : '$remainingSlots slots',
        color: cs.secondaryContainer,
        fg: cs.onSecondaryContainer,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color fg;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
