import 'package:flutter/material.dart';

import '../utils/campaign_pricing_utils.dart';

class CampaignPriceBreakdownCard extends StatelessWidget {
  final CampaignPriceBreakdown pricing;

  const CampaignPriceBreakdownCard({super.key, required this.pricing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price summary', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            _row(
              context,
              'Per cat',
              pricing.isFree
                  ? 'Free'
                  : formatCampaignMoney(pricing.unitPrice, pricing.currency),
            ),
            _row(context, 'Cats', '${pricing.quantity}'),
            const Divider(height: 20),
            _row(
              context,
              'Subtotal',
              formatCampaignMoney(pricing.subtotal, pricing.currency),
            ),
            if (pricing.discount > 0)
              _row(
                context,
                'Discount',
                '-${formatCampaignMoney(pricing.discount, pricing.currency)}',
              ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    formatCampaignMoney(pricing.total, pricing.currency),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
