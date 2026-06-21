import 'package:flutter/material.dart';

import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';

class FundraisingDonationsPreview extends StatelessWidget {
  final FundraisingCampaign campaign;
  final VoidCallback onViewAll;

  const FundraisingDonationsPreview({super.key, required this.campaign, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Donations',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onViewAll, child: const Text('View all donations')),
          ],
        ),
        if (campaign.last3Donors.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 6),
            child: Text('No donations yet'),
          )
        else
          ...campaign.last3Donors.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: (d.avatarUrl != null && d.avatarUrl!.isNotEmpty)
                        ? NetworkImage(d.avatarUrl!)
                        : null,
                    child: (d.avatarUrl == null || d.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      d.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (d.amount != null)
                    Text(
                      'donated ৳${d.amount}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
