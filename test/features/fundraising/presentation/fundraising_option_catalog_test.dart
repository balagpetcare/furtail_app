import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/presentation/fundraising_option_catalog.dart';

void main() {
  test('deduplicates options by canonical stored value', () {
    const options = <FundraisingOptionItem>[
      FundraisingOptionItem(value: 'TREATMENT', label: 'Treatment'),
      FundraisingOptionItem(value: ' treatment ', label: 'Treatment duplicate'),
      FundraisingOptionItem(value: 'RESCUE', label: 'Rescue'),
    ];

    final resolved = resolveFundraisingOptionSet('TREATMENT', options);

    expect(resolved.selectedValue, 'TREATMENT');
    expect(
      resolved.items.where((item) => item.value == 'TREATMENT'),
      hasLength(1),
    );
  });

  test('normalizes legacy aliases without losing the saved selection', () {
    final resolved = resolveFundraisingOptionSet(
      ' medical ',
      fundraisingCategoryOptions,
    );

    expect(resolved.selectedValue, 'TREATMENT');
    expect(resolved.hasLegacyValue, isFalse);
  });

  test('keeps unknown legacy values selectable and recoverable', () {
    final resolved = resolveFundraisingOptionSet(
      'SURGERY_SUPPORT',
      fundraisingCategoryOptions,
      legacyLabelBuilder: (value) => 'Legacy category: $value',
    );

    expect(resolved.selectedValue, 'SURGERY_SUPPORT');
    expect(resolved.hasLegacyValue, isTrue);
    expect(resolved.items.first.value, 'SURGERY_SUPPORT');
    expect(resolved.items.first.label, 'Legacy category: SURGERY_SUPPORT');
  });
}
