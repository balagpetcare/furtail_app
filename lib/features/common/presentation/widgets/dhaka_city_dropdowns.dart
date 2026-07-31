import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dhaka_location_providers.dart';

typedef OnChangedInt = void Function(int? value);

class DhakaCityDropdowns extends ConsumerWidget {
  final String lang; // 'en' or 'bn'
  final int? corpId;
  final int? zoneId;
  final int? wardId;

  final OnChangedInt onCorpChanged;
  final OnChangedInt onZoneChanged;
  final OnChangedInt onWardChanged;

  const DhakaCityDropdowns({
    super.key,
    required this.lang,
    required this.corpId,
    required this.zoneId,
    required this.wardId,
    required this.onCorpChanged,
    required this.onZoneChanged,
    required this.onWardChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dhakaLocationsProvider(lang));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Dhaka locations load failed: $e'),
      data: (data) {
        final corps = data.corporations;

        DhakaCorporation? selectedCorp;
        if (corpId != null) {
          for (final corp in corps) {
            if (corp.id == corpId) {
              selectedCorp = corp;
              break;
            }
          }
        }

        final zones = selectedCorp?.zones ?? const <DhakaZone>[];

        DhakaZone? selectedZone;
        if (zoneId != null) {
          for (final zone in zones) {
            if (zone.id == zoneId) {
              selectedZone = zone;
              break;
            }
          }
        }

        final wards = selectedZone?.wards ?? const <DhakaWard>[];

        if (corps.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No Dhaka city corporation data is available.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: corps.any((c) => c.id == corpId) ? corpId : null,
              decoration: const InputDecoration(labelText: 'City Corporation'),
              items: corps
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (v) {
                onCorpChanged(v);
                onZoneChanged(null);
                onWardChanged(null);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: zones.any((z) => z.id == zoneId) ? zoneId : null,
              decoration: const InputDecoration(labelText: 'Zone'),
              items: zones
                  .map(
                    (z) => DropdownMenuItem(value: z.id, child: Text(z.name)),
                  )
                  .toList(),
              onChanged: zones.isEmpty
                  ? null
                  : (v) {
                      onZoneChanged(v);
                      onWardChanged(null);
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: wards.any((w) => w.id == wardId) ? wardId : null,
              decoration: const InputDecoration(labelText: 'Ward'),
              items: wards
                  .map(
                    (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                  )
                  .toList(),
              onChanged: wards.isEmpty ? null : onWardChanged,
            ),
          ],
        );
      },
    );
  }
}
