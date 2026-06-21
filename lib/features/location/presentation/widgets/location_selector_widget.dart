import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/location/presentation/providers/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef LocationChanged = void Function(int? id, String? name);

class LocationSelectorWidget extends ConsumerWidget {
  final int? divisionId;
  final int? districtId;
  final int? upazilaId;
  final int? unionId;

  final String? divisionName;
  final String? districtName;
  final String? upazilaName;
  final String? unionName;

  final LocationChanged? onDivisionChanged;
  final LocationChanged? onDistrictChanged;
  final LocationChanged? onUpazilaChanged;
  final LocationChanged? onUnionChanged;

  final bool disabled;
  final bool required;

  const LocationSelectorWidget({
    super.key,
    required this.divisionId,
    required this.districtId,
    required this.upazilaId,
    required this.unionId,
    required this.onDivisionChanged,
    required this.onDistrictChanged,
    required this.onUpazilaChanged,
    required this.onUnionChanged,
    this.divisionName,
    this.districtName,
    this.upazilaName,
    this.unionName,
    this.disabled = false,
    this.required = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divisions = ref.watch(locationDivisionsProvider);
    final districts = divisionId == null
        ? const AsyncValue<List<BdDistrict>>.data([])
        : ref.watch(locationDistrictsProvider(divisionId!));
    final upazilas = districtId == null
        ? const AsyncValue<List<BdUpazila>>.data([])
        : ref.watch(locationUpazilasProvider(districtId!));
    final unions = upazilaId == null
        ? const AsyncValue<List<BdUnion>>.data([])
        : ref.watch(locationUnionsProvider(upazilaId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectorTile(
          label: 'Division${required ? ' *' : ''}',
          value: _resolvedNameForDivision(divisions, divisionId) ?? divisionName,
          enabled: !disabled,
          loading: divisions.isLoading,
          onTap: disabled
              ? null
              : () => _openPickerBottomSheet<BdDivision>(
                    context: context,
                    title: 'Select Division',
                    items: divisions.valueOrNull ?? const [],
                    itemLabel: (x) => x.nameEn,
                    selectedId: divisionId,
                    onPicked: (picked) {
                      // ignore: discarded_futures
                      ref.read(locationRepositoryProvider).prefetchForDivision(picked.id);
                      onDivisionChanged?.call(picked.id, picked.nameEn);
                    },
                  ),
        ),
        const SizedBox(height: 10),
        _SelectorTile(
          label: 'District${required ? ' *' : ''}',
          value: _resolvedNameForDistrict(districts, districtId) ?? districtName,
          enabled: !disabled && divisionId != null,
          loading: districts.isLoading,
          onTap: (disabled || divisionId == null)
              ? null
              : () => _openPickerBottomSheet<BdDistrict>(
                    context: context,
                    title: 'Select District',
                    items: districts.valueOrNull ?? const [],
                    itemLabel: (x) => x.nameEn,
                    selectedId: districtId,
                    onPicked: (picked) => onDistrictChanged?.call(picked.id, picked.nameEn),
                  ),
        ),
        const SizedBox(height: 10),
        _SelectorTile(
          label: 'Upazila${required ? ' *' : ''}',
          value: _resolvedNameForUpazila(upazilas, upazilaId) ?? upazilaName,
          enabled: !disabled && districtId != null,
          loading: upazilas.isLoading,
          onTap: (disabled || districtId == null)
              ? null
              : () => _openPickerBottomSheet<BdUpazila>(
                    context: context,
                    title: 'Select Upazila',
                    items: upazilas.valueOrNull ?? const [],
                    itemLabel: (x) => x.nameEn,
                    selectedId: upazilaId,
                    onPicked: (picked) => onUpazilaChanged?.call(picked.id, picked.nameEn),
                  ),
        ),
        const SizedBox(height: 10),
        _SelectorTile(
          label: 'Union${required ? ' *' : ''}',
          value: _resolvedNameForUnion(unions, unionId) ?? unionName,
          enabled: !disabled && upazilaId != null,
          loading: unions.isLoading,
          onTap: (disabled || upazilaId == null)
              ? null
              : () => _openPickerBottomSheet<BdUnion>(
                    context: context,
                    title: 'Select Union',
                    items: unions.valueOrNull ?? const [],
                    itemLabel: (x) => x.nameEn,
                    selectedId: unionId,
                    onPicked: (picked) => onUnionChanged?.call(picked.id, picked.nameEn),
                  ),
        ),
        if (divisions.hasError || districts.hasError || upazilas.hasError || unions.hasError) ...[
          const SizedBox(height: 8),
          Text(
            'Some location data failed to load. Please retry.',
            style: context.appText.bodySmall!.copyWith(color: Colors.red.shade600),
          ),
        ],
      ],
    );
  }
}

String? _resolvedNameForDivision(AsyncValue<List<BdDivision>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdDivision>[]) {
    if (item.id == id) return item.nameEn;
  }
  return null;
}

String? _resolvedNameForDistrict(AsyncValue<List<BdDistrict>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdDistrict>[]) {
    if (item.id == id) return item.nameEn;
  }
  return null;
}

String? _resolvedNameForUpazila(AsyncValue<List<BdUpazila>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdUpazila>[]) {
    if (item.id == id) return item.nameEn;
  }
  return null;
}

String? _resolvedNameForUnion(AsyncValue<List<BdUnion>> state, int? id) {
  if (id == null) return null;
  for (final item in state.valueOrNull ?? const <BdUnion>[]) {
    if (item.id == id) return item.nameEn;
  }
  return null;
}

void _openPickerBottomSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) itemLabel,
  required int? selectedId,
  required void Function(T) onPicked,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      String query = '';
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = items.where((item) {
            if (query.trim().isEmpty) return true;
            return itemLabel(item).toLowerCase().contains(query.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
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
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final row = filtered[index];
                      final label = itemLabel(row);
                      final rowId = (row as dynamic).id as int?;
                      final isSelected = rowId != null && rowId == selectedId;
                      return ListTile(
                        title: Text(label),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () {
                          onPicked(row);
                          Navigator.of(ctx).pop();
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
                value?.trim().isNotEmpty == true ? value! : 'Select',
                style: TextStyle(
                  color: value?.trim().isNotEmpty == true ? Colors.black87 : Colors.black45,
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

