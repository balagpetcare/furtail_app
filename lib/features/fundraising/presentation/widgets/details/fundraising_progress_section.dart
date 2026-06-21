import 'package:flutter/material.dart';

import 'package:bpa_app/core/constants/app_colors.dart';
import 'package:bpa_app/features/fundraising/data/models/fundraising_models.dart';

class FundraisingProgressSection extends StatelessWidget {
  final FundraisingCampaign campaign;
  const FundraisingProgressSection({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    final progress = campaign.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.donateBlue),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                '৳${campaign.stats.raisedAmount} raised',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '৳${campaign.targetAmount} target',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                'Withdrawn: ৳${campaign.stats.withdrawnAmount}',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700),
              ),
            ),
            Text(
              'Available: ৳${campaign.stats.availableAmount}',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700),
            ),
          ],
        ),
      ],
    );
  }
}
