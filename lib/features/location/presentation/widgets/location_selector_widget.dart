import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/common/presentation/providers/bd_location_providers.dart';

typedef LocationChanged = void Function(int? id, String? name);
typedef AddressModeChanged = void Function(LocationAddressMode? mode);

enum LocationAddressMode { urban, rural }

class LocationSelectorWidget extends ConsumerWidget {
  const LocationSelectorWidget({
    super.key,
    this.divisionId,
    this.districtId,
    this.addressMode,
    this.cityCorporationId,
    this.zoneId,
    this.wardId,
    this.upazilaId,
    this.unionId,
    this.areaId,
    this.divisionName,
    this.districtName,
    this.cityCorporationName,
    this.zoneName,
    this.wardName,
    this.upazilaName,
    this.unionName,
    this.areaName,
    this.onDivisionChanged,
    this.onDistrictChanged,
    this.onAddressModeChanged,
    this.onCityCorporationChanged,
    this.onZoneChanged,
    this.onWardChanged,
    this.onUpazilaChanged,
    this.onUnionChanged,
    this.onAreaChanged,
    this.disabled = false,
    this.required = false,
  });

  final int? divisionId;
  final int? districtId;
  final LocationAddressMode? addressMode;
  final int? cityCorporationId;
  final int? zoneId;
  final int? wardId;
  final int? upazilaId;
  final int? unionId;
  final int? areaId;

  final String? divisionName;
  final String? districtName;
  final String? cityCorporationName;
  final String? zoneName;
  final String? wardName;
  final String? upazilaName;
  final String? unionName;
  final String? areaName;

  final LocationChanged? onDivisionChanged;
  final LocationChanged? onDistrictChanged;
  final AddressModeChanged? onAddressModeChanged;
  final LocationChanged? onCityCorporationChanged;
  final LocationChanged? onZoneChanged;
  final LocationChanged? onWardChanged;
  final LocationChanged? onUpazilaChanged;
  final LocationChanged? onUnionChanged;
  final LocationChanged? onAreaChanged;

  final bool disabled;
  final bool required;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divisions = ref.watch(bdDivisionsProvider);
    final districts = divisionId == null
        ? const AsyncValue<List<BdDistrict>>.data(<BdDistrict>[])
        : ref.watch(bdDistrictsProvider(divisionId!));
    final urbanCorporations = districtId == null
        ? const AsyncValue<List<BdArea>>.data(<BdArea>[])
        : ref.watch(bdCityCorporationsProvider(districtId!));
    final ruralUpazilas = districtId == null
        ? const AsyncValue<List<BdUpazila>>.data(<BdUpazila>[])
        : ref.watch(bdUpazilasProvider(districtId!));

    final corporationItems = urbanCorporations.valueOrNull ?? const <BdArea>[];
    final upazilaItems = ruralUpazilas.valueOrNull ?? const <BdUpazila>[];
    final districtSupportsUrban = corporationItems.isNotEmpty;
    final districtSupportsRural = upazilaItems.isNotEmpty;

    final selectedMode = _effectiveMode(
      addressMode: addressMode,
      supportsUrban: districtSupportsUrban,
      supportsRural: districtSupportsRural,
      hasUrbanSelection:
          cityCorporationId != null || zoneId != null || wardId != null,
      hasRuralSelection: upazilaId != null || unionId != null || areaId != null,
    );

    if (addressMode == null && selectedMode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onAddressModeChanged?.call(selectedMode);
      });
    }

    final urbanZones =
        selectedMode == LocationAddressMode.urban && cityCorporationId != null
        ? ref.watch(bdZonesProvider(cityCorporationId!))
        : const AsyncValue<List<BdArea>>.data(<BdArea>[]);
    final urbanWards =
        selectedMode == LocationAddressMode.urban && zoneId != null
        ? ref.watch(bdWardsProvider(zoneId!))
        : const AsyncValue<List<BdArea>>.data(<BdArea>[]);

    final ruralUnions =
        selectedMode == LocationAddressMode.rural && upazilaId != null
        ? ref.watch(bdUnionsProvider(upazilaId!))
        : const AsyncValue<List<BdUnion>>.data(<BdUnion>[]);

    final showModePicker =
        districtId != null && districtSupportsUrban && districtSupportsRural;

    final hasAnyError =
        divisions.hasError ||
        districts.hasError ||
        urbanCorporations.hasError ||
        ruralUpazilas.hasError ||
        urbanZones.hasError ||
        urbanWards.hasError ||
        ruralUnions.hasError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectorTile(
          key: const ValueKey('bd-location-division'),
          label: 'Division${required ? ' *' : ''}',
          value:
              _resolvedNameForDivision(divisions, divisionId) ?? divisionName,
          enabled: !disabled,
          loading: divisions.isLoading,
          onTap: disabled
              ? null
              : () => _openChoiceSheet(
                  context: context,
                  title: 'Select Division',
                  items: (divisions.valueOrNull ?? const <BdDivision>[])
                      .map(
                        (item) => _Choice(
                          id: item.id,
                          label: item.display(),
                          kind: _ChoiceKind.division,
                        ),
                      )
                      .toList(),
                  selectedId: divisionId,
                  loading: divisions.isLoading,
                  error: divisions.error,
                  emptyMessage: 'No divisions available.',
                  onRetry: () => ref.invalidate(bdDivisionsProvider),
                  onPicked: (picked) =>
                      onDivisionChanged?.call(picked.id, picked.label),
                ),
        ),
        const SizedBox(height: 10),
        _SelectorTile(
          key: const ValueKey('bd-location-district'),
          label: 'District${required ? ' *' : ''}',
          value:
              _resolvedNameForDistrict(districts, districtId) ?? districtName,
          enabled: !disabled && divisionId != null,
          loading: districts.isLoading,
          onTap: (disabled || divisionId == null)
              ? null
              : () => _openChoiceSheet(
                  context: context,
                  title: 'Select District',
                  items: (districts.valueOrNull ?? const <BdDistrict>[])
                      .map(
                        (item) => _Choice(
                          id: item.id,
                          label: item.display(),
                          kind: _ChoiceKind.district,
                        ),
                      )
                      .toList(),
                  selectedId: districtId,
                  loading: districts.isLoading,
                  error: districts.error,
                  emptyMessage: 'No districts are available for this division.',
                  onRetry: () {
                    ref.invalidate(bdDivisionsProvider);
                    if (divisionId != null) {
                      ref.invalidate(bdDistrictsProvider(divisionId!));
                    }
                  },
                  onPicked: (picked) =>
                      onDistrictChanged?.call(picked.id, picked.label),
                ),
        ),
        if (showModePicker) ...[
          const SizedBox(height: 12),
          _SelectorTile(
            key: const ValueKey('bd-location-address-type'),
            label: 'Address type${required ? ' *' : ''}',
            value: addressMode == null
                ? null
                : (addressMode == LocationAddressMode.urban
                      ? 'City Corporation / Urban'
                      : 'Upazila / Thana / Rural'),
            enabled: !disabled,
            loading: false,
            onTap: disabled
                ? null
                : () => _openChoiceSheet(
                    context: context,
                    title: 'Select Address type',
                    items: [
                      const _Choice(
                        id: 1,
                        label: 'City Corporation / Urban',
                        kind: _ChoiceKind.area,
                      ),
                      const _Choice(
                        id: 2,
                        label: 'Upazila / Thana / Rural',
                        kind: _ChoiceKind.area,
                      ),
                    ],
                    selectedId: addressMode == null
                        ? null
                        : (addressMode == LocationAddressMode.urban ? 1 : 2),
                    loading: false,
                    error: null,
                    emptyMessage: 'No options available.',
                    onRetry: () {},
                    onPicked: (picked) {
                      final mode = picked.id == 1
                          ? LocationAddressMode.urban
                          : LocationAddressMode.rural;
                      onAddressModeChanged?.call(mode);
                    },
                  ),
          ),
        ],
        if (selectedMode == LocationAddressMode.urban) ...[
          const SizedBox(height: 12),
          _SelectorTile(
            key: const ValueKey('bd-location-city-corporation'),
            label: 'City Corporation${required ? ' *' : ''}',
            value:
                _resolvedNameForArea(urbanCorporations, cityCorporationId) ??
                cityCorporationName,
            enabled: !disabled && districtId != null,
            loading: urbanCorporations.isLoading,
            onTap: (disabled || districtId == null)
                ? null
                : () => _openChoiceSheet(
                    context: context,
                    title: 'Select City Corporation',
                    items: corporationItems
                        .map(
                          (item) => _Choice(
                            id: item.id,
                            label: item.display(),
                            subtitle: item.nameBn?.trim(),
                            kind: _ChoiceKind.area,
                          ),
                        )
                        .toList(),
                    selectedId: cityCorporationId,
                    loading: urbanCorporations.isLoading,
                    error: urbanCorporations.error,
                    emptyMessage:
                        'No city corporations are available for this district.',
                    onRetry: () {
                      if (districtId != null) {
                        ref.invalidate(bdCityCorporationsProvider(districtId!));
                      }
                    },
                    onPicked: (picked) =>
                        onCityCorporationChanged?.call(picked.id, picked.label),
                  ),
          ),
          const SizedBox(height: 10),
          _SelectorTile(
            key: const ValueKey('bd-location-zone'),
            label: 'Zone${required ? ' *' : ''}',
            value: _resolvedNameForArea(urbanZones, zoneId) ?? zoneName,
            enabled: !disabled && cityCorporationId != null,
            loading: urbanZones.isLoading,
            onTap: (disabled || cityCorporationId == null)
                ? null
                : () => _openChoiceSheet(
                    context: context,
                    title: 'Select Zone',
                    items: (urbanZones.valueOrNull ?? const <BdArea>[])
                        .map(
                          (item) => _Choice(
                            id: item.id,
                            label: item.display(),
                            subtitle: item.nameBn?.trim(),
                            kind: _ChoiceKind.area,
                          ),
                        )
                        .toList(),
                    selectedId: zoneId,
                    loading: urbanZones.isLoading,
                    error: urbanZones.error,
                    emptyMessage:
                        'No zones are available for this corporation.',
                    onRetry: () {
                      if (cityCorporationId != null) {
                        ref.invalidate(bdZonesProvider(cityCorporationId!));
                      }
                    },
                    onPicked: (picked) =>
                        onZoneChanged?.call(picked.id, picked.label),
                  ),
          ),
          const SizedBox(height: 10),
          _SelectorTile(
            key: const ValueKey('bd-location-ward'),
            label: 'Ward${required ? ' *' : ''}',
            value: _resolvedNameForArea(urbanWards, wardId) ?? wardName,
            enabled: !disabled && zoneId != null,
            loading: urbanWards.isLoading,
            onTap: (disabled || zoneId == null)
                ? null
                : () => _openChoiceSheet(
                    context: context,
                    title: 'Select Ward',
                    items: (urbanWards.valueOrNull ?? const <BdArea>[])
                        .map(
                          (item) => _Choice(
                            id: item.id,
                            label: item.display(),
                            subtitle: item.nameBn?.trim(),
                            kind: _ChoiceKind.area,
                          ),
                        )
                        .toList(),
                    selectedId: wardId,
                    loading: urbanWards.isLoading,
                    error: urbanWards.error,
                    emptyMessage: 'No wards are available for this zone.',
                    onRetry: () {
                      if (zoneId != null) {
                        ref.invalidate(bdWardsProvider(zoneId!));
                      }
                    },
                    onPicked: (picked) =>
                        onWardChanged?.call(picked.id, picked.label),
                  ),
          ),
          const SizedBox(height: 10),
          _LocationDetailsField(
            key: const ValueKey('bd-location-details-urban'),
            label: 'Location details',
            initialValue: areaName,
            enabled: !disabled,
            onChanged: (value) => onAreaChanged?.call(null, value),
          ),
        ] else if (selectedMode == LocationAddressMode.rural) ...[
          const SizedBox(height: 12),
          _SelectorTile(
            key: const ValueKey('bd-location-upazila'),
            label: 'Upazila / Thana${required ? ' *' : ''}',
            value:
                _resolvedNameForUpazila(ruralUpazilas, upazilaId) ??
                upazilaName,
            enabled: !disabled && districtId != null,
            loading: ruralUpazilas.isLoading,
            onTap: (disabled || districtId == null)
                ? null
                : () => _openChoiceSheet(
                    context: context,
                    title: 'Select Upazila / Thana',
                    items: (ruralUpazilas.valueOrNull ?? const <BdUpazila>[])
                        .map(
                          (item) => _Choice(
                            id: item.id,
                            label: item.display(),
                            kind: _ChoiceKind.upazila,
                          ),
                        )
                        .toList(),
                    selectedId: upazilaId,
                    loading: ruralUpazilas.isLoading,
                    error: ruralUpazilas.error,
                    emptyMessage:
                        'No upazilas or thanas are available for this district.',
                    onRetry: () {
                      if (districtId != null) {
                        ref.invalidate(bdUpazilasProvider(districtId!));
                      }
                    },
                    onPicked: (picked) =>
                        onUpazilaChanged?.call(picked.id, picked.label),
                  ),
          ),
          const SizedBox(height: 10),
          _SelectorTile(
            key: const ValueKey('bd-location-union'),
            label: 'Union${required ? ' *' : ''}',
            value: _resolvedNameForUnion(ruralUnions, unionId) ?? unionName,
            enabled: !disabled && upazilaId != null,
            loading: ruralUnions.isLoading,
            onTap: (disabled || upazilaId == null)
                ? null
                : () => _openChoiceSheet(
                    context: context,
                    title: 'Select Union',
                    items: (ruralUnions.valueOrNull ?? const <BdUnion>[])
                        .map(
                          (item) => _Choice(
                            id: item.id,
                            label: item.display(),
                            kind: _ChoiceKind.union,
                          ),
                        )
                        .toList(),
                    selectedId: unionId,
                    loading: ruralUnions.isLoading,
                    error: ruralUnions.error,
                    emptyMessage: 'No unions are available for this upazila.',
                    onRetry: () {
                      if (upazilaId != null) {
                        ref.invalidate(bdUnionsProvider(upazilaId!));
                      }
                    },
                    onPicked: (picked) =>
                        onUnionChanged?.call(picked.id, picked.label),
                  ),
          ),
          const SizedBox(height: 10),
          _LocationDetailsField(
            key: const ValueKey('bd-location-details-rural'),
            label: 'Location details',
            initialValue: areaName,
            enabled: !disabled,
            onChanged: (value) => onAreaChanged?.call(null, value),
          ),
        ] else if (districtId != null) ...[
          const SizedBox(height: 12),
          Text(
            districtSupportsUrban && districtSupportsRural
                ? 'Choose Urban or Rural address mode to continue.'
                : districtSupportsUrban
                ? 'Urban address mode is available for this district.'
                : 'Rural address mode is available for this district.',
            style: context.appText.bodySmall!.copyWith(
              color: Colors.blueGrey.shade700,
            ),
          ),
        ],
        if (hasAnyError) ...[
          const SizedBox(height: 8),
          Text(
            'Some location data failed to load. Please retry.',
            style: context.appText.bodySmall!.copyWith(
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                ref.invalidate(bdDivisionsProvider);
                if (divisionId != null) {
                  ref.invalidate(bdDistrictsProvider(divisionId!));
                }
                if (districtId != null) {
                  ref.invalidate(bdCityCorporationsProvider(districtId!));
                  ref.invalidate(bdUpazilasProvider(districtId!));
                }
                if (cityCorporationId != null) {
                  ref.invalidate(bdZonesProvider(cityCorporationId!));
                }
                if (zoneId != null) {
                  ref.invalidate(bdWardsProvider(zoneId!));
                }
                if (upazilaId != null) {
                  ref.invalidate(bdUnionsProvider(upazilaId!));
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}

LocationAddressMode? _effectiveMode({
  required LocationAddressMode? addressMode,
  required bool supportsUrban,
  required bool supportsRural,
  required bool hasUrbanSelection,
  required bool hasRuralSelection,
}) {
  if (addressMode != null) return addressMode;
  if (hasUrbanSelection) return LocationAddressMode.urban;
  if (hasRuralSelection) return LocationAddressMode.rural;
  if (supportsUrban && !supportsRural) return LocationAddressMode.urban;
  if (supportsRural && !supportsUrban) return LocationAddressMode.rural;
  return null;
}

String? _resolvedNameForDivision(AsyncValue<List<BdDivision>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdDivision>[]) {
    if (item.id == id) return item.display();
  }
  return null;
}

String? _resolvedNameForDistrict(AsyncValue<List<BdDistrict>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdDistrict>[]) {
    if (item.id == id) return item.display();
  }
  return null;
}

String? _resolvedNameForUpazila(AsyncValue<List<BdUpazila>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdUpazila>[]) {
    if (item.id == id) return item.display();
  }
  return null;
}

String? _resolvedNameForUnion(AsyncValue<List<BdUnion>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdUnion>[]) {
    if (item.id == id) return item.display();
  }
  return null;
}

String? _resolvedNameForArea(AsyncValue<List<BdArea>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdArea>[]) {
    if (item.id == id) return item.display();
  }
  return null;
}

void _openChoiceSheet({
  required BuildContext context,
  required String title,
  required List<_Choice> items,
  required int? selectedId,
  required bool loading,
  required Object? error,
  required String emptyMessage,
  required VoidCallback onRetry,
  required ValueChanged<_Choice> onPicked,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      String query = '';
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final filtered = items.where((item) {
            if (query.trim().isEmpty) return true;
            return item.label.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: context.appText.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setSheetState(() => query = value),
                ),
                const SizedBox(height: 10),
                if (loading && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (error != null && items.isEmpty) ...[
                  Text(
                    'Unable to load locations right now. Please try again.',
                    textAlign: TextAlign.center,
                    style: context.appText.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      onRetry();
                      Navigator.of(sheetContext).pop();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ] else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      query.trim().isEmpty
                          ? emptyMessage
                          : 'No matching locations found.',
                      textAlign: TextAlign.center,
                      style: context.appText.bodyMedium,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = filtered[index];
                        final isSelected = row.id == selectedId;
                        return ListTile(
                          title: Text(row.label),
                          subtitle: row.subtitle == null
                              ? null
                              : Text(row.subtitle!),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null,
                          onTap: () {
                            onPicked(row);
                            Navigator.of(sheetContext).pop();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _Choice {
  const _Choice({
    required this.id,
    required this.label,
    required this.kind,
    this.subtitle,
  });

  final int id;
  final String label;
  final String? subtitle;
  final _ChoiceKind kind;
}

enum _ChoiceKind { division, district, upazila, union, area }

/// Area selector for the rural (union) branch — distinguishes loading,
/// error/retry, "no predefined areas" (optional manual entry), and normal
/// picker states instead of always opening a bottom sheet that might turn
/// out empty.
class _RuralAreaField extends StatefulWidget {
  const _RuralAreaField({
    required this.unionId,
    required this.areaId,
    required this.areaName,
    required this.ruralAreas,
    required this.disabled,
    required this.required,
    required this.onAreaChanged,
    required this.onRetry,
  });

  final int? unionId;
  final int? areaId;
  final String? areaName;
  final AsyncValue<List<BdArea>> ruralAreas;
  final bool disabled;
  final bool required;
  final LocationChanged? onAreaChanged;
  final VoidCallback onRetry;

  @override
  State<_RuralAreaField> createState() => _RuralAreaFieldState();
}

class _RuralAreaFieldState extends State<_RuralAreaField> {
  late final TextEditingController _manualController;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(
      text: widget.areaId == null ? (widget.areaName ?? '') : '',
    );
  }

  @override
  void didUpdateWidget(covariant _RuralAreaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unionId != oldWidget.unionId) {
      // A new union was selected — the manually typed neighbourhood for the
      // previous union no longer applies.
      _manualController.clear();
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unionId == null) {
      return _SelectorTile(
        key: const ValueKey('bd-location-area-rural'),
        label: 'Area',
        value: null,
        enabled: false,
        loading: false,
        onTap: null,
      );
    }

    if (widget.ruralAreas.isLoading) {
      return const _AreaStatusTile(
        key: ValueKey('bd-location-area-rural-loading'),
        label: 'Area',
        loading: true,
        message: 'Loading available areas...',
      );
    }

    if (widget.ruralAreas.hasError) {
      return _AreaStatusTile(
        key: const ValueKey('bd-location-area-rural-error'),
        label: 'Area',
        message: 'Unable to load areas for this union.',
        isError: true,
        onRetry: widget.onRetry,
      );
    }

    final areas = widget.ruralAreas.valueOrNull ?? const <BdArea>[];
    if (areas.isEmpty) {
      return Container(
        key: const ValueKey('bd-location-area-rural-empty'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kept as plain "Area" (never "Area *") so it stays obviously
            // optional even though the usual selector tile is replaced.
            Text(
              'Area',
              style: context.appText.bodySmall!.copyWith(
                color: Colors.blueGrey.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.blueGrey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No predefined areas available for this union.',
                    style: context.appText.bodySmall!.copyWith(
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('bd-location-area-manual-input'),
              controller: _manualController,
              enabled: !widget.disabled,
              decoration: const InputDecoration(
                labelText: 'Area / neighbourhood (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                final trimmed = value.trim();
                widget.onAreaChanged?.call(
                  null,
                  trimmed.isEmpty ? null : trimmed,
                );
              },
            ),
          ],
        ),
      );
    }

    return _SelectorTile(
      key: const ValueKey('bd-location-area-rural'),
      label: 'Area${widget.required ? ' *' : ''}',
      value:
          _resolvedNameForArea(widget.ruralAreas, widget.areaId) ??
          widget.areaName,
      enabled: !widget.disabled,
      loading: false,
      onTap: widget.disabled
          ? null
          : () => _openChoiceSheet(
              context: context,
              title: 'Select Area',
              items: areas
                  .map(
                    (item) => _Choice(
                      id: item.id,
                      label: item.display(),
                      subtitle: item.nameBn?.trim(),
                      kind: _ChoiceKind.area,
                    ),
                  )
                  .toList(),
              selectedId: widget.areaId,
              loading: false,
              error: null,
              emptyMessage: 'No areas are available for this union.',
              onRetry: widget.onRetry,
              onPicked: (picked) =>
                  widget.onAreaChanged?.call(picked.id, picked.label),
            ),
    );
  }
}

/// A non-interactive loading or error row for the area field, shown instead
/// of opening a bottom sheet with nothing meaningful in it yet.
class _AreaStatusTile extends StatelessWidget {
  const _AreaStatusTile({
    super.key,
    required this.label,
    required this.message,
    this.loading = false,
    this.isError = false,
    this.onRetry,
  });

  final String label;
  final String message;
  final bool loading;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isError)
            Icon(Icons.error_outline, size: 18, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.appText.bodySmall!.copyWith(
                color: isError
                    ? Colors.red.shade700
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (isError && onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _LocationDetailsField extends StatefulWidget {
  const _LocationDetailsField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String? initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_LocationDetailsField> createState() => _LocationDetailsFieldState();
}

class _LocationDetailsFieldState extends State<_LocationDetailsField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant _LocationDetailsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nextValue = widget.initialValue ?? '';
        if (_controller.text != nextValue) {
          _controller.text = nextValue;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'Apartment, landmark, village, or other details',
        border: const OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
    );
  }
}

class _SelectorTile extends StatelessWidget {
  const _SelectorTile({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final String? value;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value?.trim().isNotEmpty == true;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabled: enabled,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? value! : 'Select',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasValue
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.keyboard_arrow_down,
                color: enabled
                    ? scheme.onSurfaceVariant
                    : scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}
