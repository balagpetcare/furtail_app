import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/vaccination_platform/campaign_booking_flow.dart';
import '../providers/campaign_booking_location_providers.dart';

class CityCorporationAreaPicker extends ConsumerWidget {
  final String cityCorporationCode;
  final int? bdAreaId;
  final ValueChanged<DhakaCityCorporation> onCorporationChanged;
  final ValueChanged<DhakaBookingArea> onAreaChanged;
  final String? corpError;
  final String? areaError;

  const CityCorporationAreaPicker({
    super.key,
    required this.cityCorporationCode,
    required this.bdAreaId,
    required this.onCorporationChanged,
    required this.onAreaChanged,
    this.corpError,
    this.areaError,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corpsAsync = ref.watch(dhakaCityCorporationsProvider);
    final areasAsync = cityCorporationCode.isEmpty
        ? const AsyncValue<List<DhakaBookingArea>>.data([])
        : ref.watch(dhakaBookingAreasProvider(cityCorporationCode));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('City Corporation', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        corpsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load city corporations.'),
          data: (corps) {
            return DropdownButtonFormField<String>(
              initialValue: cityCorporationCode.isEmpty ? null : cityCorporationCode,
              decoration: InputDecoration(
                labelText: 'Select corporation',
                errorText: corpError,
                border: const OutlineInputBorder(),
              ),
              items: corps
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.code,
                      child: Text(c.displayLabel),
                    ),
                  )
                  .toList(),
              onChanged: (code) {
                if (code == null) return;
                final corp = corps.firstWhere((c) => c.code == code);
                onCorporationChanged(corp);
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Area', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        areasAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load areas.'),
          data: (areas) {
            if (cityCorporationCode.isEmpty) {
              return const Text('Select a city corporation first.');
            }
            if (areas.isEmpty) {
              return const Text('No areas available for this corporation.');
            }
            return DropdownButtonFormField<int>(
              initialValue: bdAreaId,
              decoration: InputDecoration(
                labelText: 'Select your area',
                errorText: areaError,
                border: const OutlineInputBorder(),
              ),
              items: areas
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.nameEn),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                final area = areas.firstWhere((a) => a.id == id);
                onAreaChanged(area);
              },
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Your vaccination center will be assigned automatically based on area capacity.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
