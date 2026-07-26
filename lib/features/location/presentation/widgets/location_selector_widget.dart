import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/common/presentation/providers/bd_location_providers.dart';

typedef LocationChanged = void Function(int? id, String? name);

class LocationSelectorWidget extends ConsumerWidget {
  final int? divisionId;
  final int? districtId;
  final int? upazilaId;
  final int? unionId;
  final int? areaId;

  final String? divisionName;
  final String? districtName;
  final String? upazilaName;
  final String? unionName;
  final String? areaName;

  final LocationChanged? onDivisionChanged;
  final LocationChanged? onDistrictChanged;
  final LocationChanged? onUpazilaChanged;
  final LocationChanged? onUnionChanged;
  final LocationChanged? onAreaChanged;

  final bool disabled;
  final bool required;

  const LocationSelectorWidget({
    super.key,
    required this.divisionId,
    required this.districtId,
    required this.upazilaId,
    required this.unionId,
    this.areaId,
    required this.onDivisionChanged,
    required this.onDistrictChanged,
    required this.onUpazilaChanged,
    required this.onUnionChanged,
    this.onAreaChanged,
    this.divisionName,
    this.districtName,
    this.upazilaName,
    this.unionName,
    this.areaName,
    this.disabled = false,
    this.required = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divisions = ref.watch(bdDivisionsProvider);
    final districts = divisionId == null
        ? const AsyncValue<List<BdDistrict>>.data([])
        : ref.watch(bdDistrictsProvider(divisionId!));
    final upazilas = districtId == null
        ? const AsyncValue<List<BdUpazila>>.data([])
        : ref.watch(bdUpazilasProvider(districtId!));
    final unions = upazilaId == null
        ? const AsyncValue<List<BdUnion>>.data([])
        : ref.watch(bdUnionsProvider(upazilaId!));
    final areas = upazilaId == null
        ? const AsyncValue<List<BdArea>>.data([])
        : ref.watch(bdAreasProvider(upazilaId!));

    final unionItems = unions.valueOrNull ?? const <BdUnion>[];
    final areaItems = areas.valueOrNull ?? const <BdArea>[];
    final useAreaMode =
        upazilaId != null && unionItems.isEmpty && areaItems.isNotEmpty;
    final lastLabel = useAreaMode
        ? 'Union / Ward${required ? ' *' : ''}'
        : 'Union${required ? ' *' : ''}';
    final lastLoading = unions.isLoading || areas.isLoading;
    final lastError = unions.error ?? areas.error;
    final lastOptions = useAreaMode
        ? areaItems
              .map(
                (item) => _LocationChoice(
                  id: item.id,
                  label: item.display(),
                  subtitle: item.type.trim().isEmpty ? null : item.type,
                  kind: _LocationChoiceKind.area,
                ),
              )
              .toList()
        : unionItems
              .map(
                (item) => _LocationChoice(
                  id: item.id,
                  label: item.display(),
                  subtitle: null,
                  kind: _LocationChoiceKind.union,
                ),
              )
              .toList();
    final lastSelectedId = useAreaMode ? areaId : unionId;
    final lastSelectedName = useAreaMode
        ? _resolvedNameForArea(areas, areaId) ?? areaName ?? unionName
        : _resolvedNameForUnion(unions, unionId) ?? unionName ?? areaName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectorTile(
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
                        (item) => _LocationChoice(
                          id: item.id,
                          label: item.display(),
                          subtitle: null,
                          kind: _LocationChoiceKind.division,
                        ),
                      )
                      .toList(),
                  selectedId: divisionId,
                  loading: divisions.isLoading,
                  error: divisions.error,
                  emptyMessage: 'No divisions available.',
                  onRetry: () => ref.invalidate(bdDivisionsProvider),
                  onPicked: (picked) {
                    onDivisionChanged?.call(picked.id, picked.label);
                  },
                ),
        ),
        const SizedBox(height: 10),
        _SelectorTile(
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
                        (item) => _LocationChoice(
                          id: item.id,
                          label: item.display(),
                          subtitle: null,
                          kind: _LocationChoiceKind.district,
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
        const SizedBox(height: 10),
        _SelectorTile(
          label: 'Upazila / Thana${required ? ' *' : ''}',
          value: _resolvedNameForUpazila(upazilas, upazilaId) ?? upazilaName,
          enabled: !disabled && districtId != null,
          loading: upazilas.isLoading,
          onTap: (disabled || districtId == null)
              ? null
              : () => _openChoiceSheet(
                  context: context,
                  title: 'Select Upazila / Thana',
                  items: (upazilas.valueOrNull ?? const <BdUpazila>[])
                      .map(
                        (item) => _LocationChoice(
                          id: item.id,
                          label: item.display(),
                          subtitle: null,
                          kind: _LocationChoiceKind.upazila,
                        ),
                      )
                      .toList(),
                  selectedId: upazilaId,
                  loading: upazilas.isLoading,
                  error: upazilas.error,
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
          label: lastLabel,
          value: lastSelectedName,
          enabled: !disabled && upazilaId != null,
          loading: lastLoading,
          onTap: (disabled || upazilaId == null)
              ? null
              : () => _openChoiceSheet(
                  context: context,
                  title: useAreaMode ? 'Select Ward / Area' : 'Select Union',
                  items: lastOptions,
                  selectedId: lastSelectedId,
                  loading: lastLoading,
                  error: lastError,
                  emptyMessage: useAreaMode
                      ? 'No ward or area options are available for this upazila.'
                      : 'No union options are available for this upazila.',
                  onRetry: () {
                    ref.invalidate(bdUnionsProvider(upazilaId!));
                    ref.invalidate(bdAreasProvider(upazilaId!));
                  },
                  onPicked: (picked) {
                    if (picked.kind == _LocationChoiceKind.area) {
                      (onAreaChanged ?? onUnionChanged)?.call(
                        picked.id,
                        picked.label,
                      );
                      return;
                    }
                    onUnionChanged?.call(picked.id, picked.label);
                  },
                ),
        ),
        if (divisions.hasError ||
            districts.hasError ||
            upazilas.hasError ||
            unions.hasError ||
            areas.hasError) ...[
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
                  ref.invalidate(bdUpazilasProvider(districtId!));
                }
                if (upazilaId != null) {
                  ref.invalidate(bdUnionsProvider(upazilaId!));
                  ref.invalidate(bdAreasProvider(upazilaId!));
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
  required List<_LocationChoice> items,
  required int? selectedId,
  required bool loading,
  required Object? error,
  required String emptyMessage,
  required VoidCallback onRetry,
  required ValueChanged<_LocationChoice> onPicked,
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
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

class _LocationChoice {
  const _LocationChoice({
    required this.id,
    required this.label,
    required this.kind,
    this.subtitle,
  });

  final int id;
  final String label;
  final String? subtitle;
  final _LocationChoiceKind kind;
}

enum _LocationChoiceKind { division, district, upazila, union, area }

class _SelectorTile extends StatelessWidget {
  final String label;
  final String? value;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  const _SelectorTile({
    required this.label,
    required this.value,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value?.trim().isNotEmpty == true;
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
                  color: hasValue ? Colors.black87 : Colors.black45,
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
                color: enabled ? Colors.black54 : Colors.black26,
              ),
          ],
        ),
      ),
    );
  }
}
