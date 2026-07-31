import 'package:flutter/material.dart';

import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/presentation/utils/fundraising_formatters.dart';

class FundraisingDonationsPreview extends StatelessWidget {
  const FundraisingDonationsPreview({
    super.key,
    required this.campaign,
    required this.onViewAll,
  });

  final FundraisingCampaign campaign;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (campaign.last3Donors.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.48,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              color: theme.colorScheme.primary,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first supporter',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No donations have been recorded yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < campaign.last3Donors.length; index++) ...[
          _DonationRow(donor: campaign.last3Donors[index]),
          if (index != campaign.last3Donors.length - 1)
            Divider(
              height: 24,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('View all donations'),
          ),
        ),
      ],
    );
  }
}

class _DonationRow extends StatelessWidget {
  const _DonationRow({required this.donor});

  final FundraisingDonor donor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage:
              (donor.avatarUrl != null && donor.avatarUrl!.trim().isNotEmpty)
              ? NetworkImage(donor.avatarUrl!)
              : null,
          child: (donor.avatarUrl == null || donor.avatarUrl!.trim().isEmpty)
              ? Icon(Icons.person_outline, color: theme.colorScheme.primary)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                donor.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Supported this fundraiser',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (donor.amount != null)
          Text(
            formatFundraisingMoney(context, donor.amount!),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}
