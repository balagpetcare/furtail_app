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
            colorScheme.surfaceContainerHighest,
            colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fundraising progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6C945).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${percentage.clamp(0, 999)}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF5C4300),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFF6C945),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              overfunded
                  ? 'This fundraiser is beyond its original target.'
                  : target <= 0
                  ? 'This fundraiser does not have a fixed target yet.'
                  : 'Supporters have helped cover part of the goal.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryCell(
                  label: 'Raised',
                  value: formatFundraisingMoney(context, raised),
                  emphasis: true,
                ),
                _SummaryCell(
                  label: 'Target',
                  value: formatFundraisingMoney(context, target),
                ),
                _SummaryCell(
                  label: 'Remaining',
                  value: formatFundraisingMoney(context, remaining),
                ),
                _SummaryCell(
                  label: 'Withdrawn',
                  value: formatFundraisingMoney(context, withdrawn),
                ),
                _SummaryCell(
                  label: 'Available',
                  value: formatFundraisingMoney(context, available),
                  emphasis: true,
                ),
                _SummaryCell(
                  label: 'Donors',
                  value: '${campaign.stats.donorsCount}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.of(context).size.width - 72) / 2;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: width, maxWidth: width),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: emphasis
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.45)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
