import 'package:flutter/material.dart';

class AppDateField extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onTap;
  final String? errorText;

  const AppDateField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    // controller না, initialValue ব্যবহার → memory leak safe
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      initialValue: valueText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_month),
        suffixIcon: const Icon(Icons.arrow_drop_down),
        errorText: errorText,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
