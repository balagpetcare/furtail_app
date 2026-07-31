import 'package:flutter/material.dart';

import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/presentation/utils/fundraising_formatters.dart';

class FundraisingProgressSection extends StatelessWidget {
  const FundraisingProgressSection({super.key, required this.campaign});

  final FundraisingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final target = campaign.targetAmountMinor ?? campaign.targetAmount;
    final raised = campaign.stats.raisedAmount;
    final withdrawn = campaign.stats.withdrawnAmount;
    final available = campaign.stats.availableAmount;
    final remaining = campaign.remainingAmount;
    final progress = target <= 0
        ? 0.0
        : (raised / target).clamp(0, 1).toDouble();
    final percentage = target <= 0 ? 0 : ((raised / target) * 100).round();
    final overfunded = target > 0 && raised > target;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.primaryContainer.withValues(alpha: 0.38),
            colorScheme.surfaceContainerLowest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fundraising progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        overfunded
                            ? 'The original target has been exceeded.'
                            : target <= 0
                            ? 'This campaign does not have a fixed target.'
                            : 'Every contribution moves this campaign forward.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${percentage.clamp(0, 999)}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.72),
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raised so far',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    formatFundraisingMoney(context, raised),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryCell(
                      width: cellWidth,
                      icon: Icons.flag_outlined,
                      label: 'Target',
                      value: formatFundraisingMoney(context, target),
                    ),
                    _SummaryCell(
                      width: cellWidth,
                      icon: Icons.trending_up_rounded,
                      label: 'Remaining',
                      value: formatFundraisingMoney(context, remaining),
                    ),
                    _SummaryCell(
                      width: cellWidth,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Available',
                      value: formatFundraisingMoney(context, available),
                    ),
                    _SummaryCell(
                      width: cellWidth,
                      icon: Icons.people_alt_outlined,
                      label: 'Donors',
                      value: '${campaign.stats.donorsCount}',
                    ),
                  ],
                );
              },
            ),
            if (withdrawn > 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Withdrawn ${formatFundraisingMoney(context, withdrawn)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
