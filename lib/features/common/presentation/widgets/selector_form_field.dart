import 'package:flutter/material.dart';

import 'searchable_selector_sheet.dart';

/// A form-field-styled trigger that opens a [showSearchableSelectorSheet]
/// instead of an inline dropdown overlay — avoids the "oversized menu
/// covers the form" problem `DropdownButtonFormField` has with long lists,
/// while keeping the same visual slot in a form.
class SelectorFormField<T> extends StatelessWidget {
  const SelectorFormField({
    super.key,
    required this.label,
    required this.selectedLabel,
    required this.load,
    required this.onSelected,
    this.value,
    this.enabled = true,
    this.disabledHint,
    this.errorText,
    this.searchHint = 'Search',
    this.emptyMessage = 'No options available.',
    this.equals,
  });

  final String label;
  final String? selectedLabel;
  final T? value;
  final bool enabled;
  final String? disabledHint;
  final String? errorText;
  final String searchHint;
  final String emptyMessage;
  final SelectorLoader<SelectorItem<T>> load;
  final ValueChanged<T> onSelected;
  final bool Function(T a, T b)? equals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText =
        selectedLabel ??
        (enabled ? 'Select $label' : (disabledHint ?? 'Select $label'));
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. ${selectedLabel ?? 'Not selected'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: !enabled
            ? null
            : () async {
                final picked = await showSearchableSelectorSheet<T>(
                  context: context,
                  title: label,
                  load: load,
                  selectedValue: value,
                  searchHint: searchHint,
                  emptyMessage: emptyMessage,
                  equals: equals,
                );
                if (picked != null) onSelected(picked);
              },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            enabled: enabled,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            displayText,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: selectedLabel == null
                ? theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)
                : theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
