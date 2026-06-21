import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/campaign_providers.dart';
import '../utils/campaign_format_utils.dart';

class CampaignBenefitsScreen extends ConsumerWidget {
  const CampaignBenefitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benefitsAsync = ref.watch(campaignBenefitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Benefits')),
      body: benefitsAsync.when(
        data: (b) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              b.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (b.description != null) ...[
              const SizedBox(height: 8),
              Text(b.description!),
            ],
            const SizedBox(height: 12),
            if (b.startDate != null && b.endDate != null)
              Text(
                '${formatCampaignDate(b.startDate)} – ${formatCampaignDate(b.endDate)}',
              ),
            if (b.priceAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Price: ৳${b.priceAmount} (${b.pricingType ?? 'campaign'})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 16),
            Text('Benefits', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...b.benefits.map(
              (item) => ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(item),
                dense: true,
              ),
            ),
            if (b.vaccineTypes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Vaccines included', style: Theme.of(context).textTheme.titleMedium),
              ...b.vaccineTypes.map(
                (v) => ListTile(
                  leading: const Icon(Icons.vaccines),
                  title: Text(v['name']?.toString() ?? 'Vaccine'),
                  subtitle: v['description'] != null
                      ? Text(v['description'].toString())
                      : null,
                ),
              ),
            ],
            if (b.locations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Locations', style: Theme.of(context).textTheme.titleMedium),
              ...b.locations.map(
                (loc) => ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(loc['name']?.toString() ?? 'Location'),
                  subtitle: loc['address'] != null
                      ? Text(loc['address'].toString())
                      : null,
                ),
              ),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}
