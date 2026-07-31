import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';

class FundraisingCountdownCard extends StatefulWidget {
  const FundraisingCountdownCard({super.key, required this.campaign});

  final FundraisingCampaign campaign;

  @override
  State<FundraisingCountdownCard> createState() =>
      _FundraisingCountdownCardState();
}

class _FundraisingCountdownCardState extends State<FundraisingCountdownCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  DateTime? get _endAt => widget.campaign.endsAt ?? widget.campaign.deadline;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant FundraisingCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.campaign.endsAt ?? oldWidget.campaign.deadline) != _endAt) {
      _startTicker();
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _now = DateTime.now();
    if (_endAt == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      if (!_endAt!.isAfter(_now)) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final endAt = _endAt;
    if (endAt == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final remaining = endAt.difference(_now);
    final expired = remaining.inSeconds <= 0;
    final safe = expired ? Duration.zero : remaining;
    final days = safe.inDays;
    final hours = safe.inHours.remainder(24);
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: expired
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.55)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  expired ? Icons.event_busy_outlined : Icons.timer_outlined,
                  color: expired
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    expired ? 'Fundraiser ended' : 'Time remaining',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (expired)
              Text(
                'The campaign deadline has passed. New donations may be unavailable.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  height: 1.4,
                ),
              )
            else
              Row(
                children: [
                  _CountdownUnit(value: days, label: 'Days'),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: hours, label: 'Hours'),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: minutes, label: 'Minutes'),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: seconds, label: 'Seconds'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
