class FundraisingOptionItem {
  const FundraisingOptionItem({
    required this.value,
    required this.label,
    this.aliases = const <String>[],
  });

  final String value;
  final String label;
  final List<String> aliases;
}

class FundraisingResolvedOptionSet {
  const FundraisingResolvedOptionSet({
    required this.items,
    required this.selectedValue,
    required this.hasLegacyValue,
  });

  final List<FundraisingOptionItem> items;
  final String? selectedValue;
  final bool hasLegacyValue;
}

String? normalizeFundraisingOptionValue(
  String? raw,
  List<FundraisingOptionItem> options,
) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final normalized = _normalizeOptionKey(trimmed);
  for (final option in options) {
    if (_normalizeOptionKey(option.value) == normalized) {
      return option.value;
    }
    for (final alias in option.aliases) {
      if (_normalizeOptionKey(alias) == normalized) {
        return option.value;
      }
    }
  }
  return trimmed;
}

FundraisingResolvedOptionSet resolveFundraisingOptionSet(
  String? rawValue,
  List<FundraisingOptionItem> options, {
  String Function(String rawValue)? legacyLabelBuilder,
}) {
  final deduped = <FundraisingOptionItem>[];
  final seenValues = <String>{};
  for (final option in options) {
    final canonicalValue = normalizeFundraisingOptionValue(
      option.value,
      options,
    );
    if (canonicalValue == null || !seenValues.add(canonicalValue)) {
      continue;
    }
    deduped.add(
      FundraisingOptionItem(
        value: canonicalValue,
        label: option.label,
        aliases: option.aliases,
      ),
    );
  }

  final normalizedValue = normalizeFundraisingOptionValue(rawValue, deduped);
  final matchingItems = normalizedValue == null
      ? const <FundraisingOptionItem>[]
      : deduped.where((item) => item.value == normalizedValue).toList();
  if (matchingItems.length == 1) {
    return FundraisingResolvedOptionSet(
      items: deduped,
      selectedValue: normalizedValue,
      hasLegacyValue: false,
    );
  }

  final trimmed = rawValue?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return FundraisingResolvedOptionSet(
      items: deduped,
      selectedValue: null,
      hasLegacyValue: false,
    );
  }

  final legacyValue = trimmed;
  final legacyItem = FundraisingOptionItem(
    value: legacyValue,
    label: legacyLabelBuilder?.call(legacyValue) ?? 'Legacy: $legacyValue',
  );
  return FundraisingResolvedOptionSet(
    items: <FundraisingOptionItem>[legacyItem, ...deduped],
    selectedValue: legacyValue,
    hasLegacyValue: true,
  );
}

String _normalizeOptionKey(String raw) {
  final upper = raw.trim().toUpperCase();
  return upper.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
}

const List<FundraisingOptionItem> fundraisingCategoryOptions =
    <FundraisingOptionItem>[
      FundraisingOptionItem(
        value: 'TREATMENT',
        label: 'Treatment',
        aliases: <String>['Treatment', 'MEDICAL', 'PET_HEALTH', 'HEALTH'],
      ),
      FundraisingOptionItem(
        value: 'RESCUE',
        label: 'Rescue',
        aliases: <String>['Rescue'],
      ),
      FundraisingOptionItem(
        value: 'SHELTER',
        label: 'Shelter',
        aliases: <String>['Shelter'],
      ),
      FundraisingOptionItem(
        value: 'FOOD',
        label: 'Food',
        aliases: <String>['Food'],
      ),
      FundraisingOptionItem(
        value: 'EQUIPMENT',
        label: 'Equipment',
        aliases: <String>['Equipment', 'SUPPLIES'],
      ),
      FundraisingOptionItem(
        value: 'OTHER',
        label: 'Other',
        aliases: <String>['Other'],
      ),
    ];

const List<FundraisingOptionItem> fundraisingBeneficiaryTypeOptions =
    <FundraisingOptionItem>[
      FundraisingOptionItem(
        value: 'PET',
        label: 'Pet',
        aliases: <String>['Pet', 'ANIMAL'],
      ),
      FundraisingOptionItem(
        value: 'PERSON',
        label: 'Person',
        aliases: <String>['Person', 'HUMAN'],
      ),
      FundraisingOptionItem(
        value: 'SHELTER',
        label: 'Shelter',
        aliases: <String>['Shelter'],
      ),
      FundraisingOptionItem(
        value: 'ORGANIZATION',
        label: 'Organization',
        aliases: <String>['Organization', 'ORG'],
      ),
      FundraisingOptionItem(
        value: 'COMMUNITY',
        label: 'Community',
        aliases: <String>['Community'],
      ),
      FundraisingOptionItem(
        value: 'OTHER',
        label: 'Other',
        aliases: <String>['Other'],
      ),
    ];

const List<FundraisingOptionItem> fundraisingUrgencyOptions =
    <FundraisingOptionItem>[
      FundraisingOptionItem(
        value: 'LOW',
        label: 'Low',
        aliases: <String>['Low'],
      ),
      FundraisingOptionItem(
        value: 'MEDIUM',
        label: 'Medium',
        aliases: <String>['Medium'],
      ),
      FundraisingOptionItem(
        value: 'HIGH',
        label: 'High',
        aliases: <String>['High'],
      ),
      FundraisingOptionItem(
        value: 'CRITICAL',
        label: 'Critical',
        aliases: <String>['Critical', 'URGENT'],
      ),
    ];

const List<FundraisingOptionItem> fundraisingEditableStatusOptions =
    <FundraisingOptionItem>[
      FundraisingOptionItem(
        value: 'PENDING_REVIEW',
        label: 'Pending review',
        aliases: <String>['Pending review'],
      ),
      FundraisingOptionItem(
        value: 'ACTIVE',
        label: 'Active',
        aliases: <String>['Active', 'PUBLISHED', 'APPROVED'],
      ),
      FundraisingOptionItem(
        value: 'PAUSED',
        label: 'Paused',
        aliases: <String>['Paused'],
      ),
      FundraisingOptionItem(
        value: 'FUNDED',
        label: 'Funded',
        aliases: <String>['Funded'],
      ),
      FundraisingOptionItem(
        value: 'COMPLETED',
        label: 'Completed',
        aliases: <String>['Completed', 'ENDED'],
      ),
      FundraisingOptionItem(
        value: 'CANCELLED',
        label: 'Cancelled',
        aliases: <String>['Cancelled'],
      ),
      FundraisingOptionItem(
        value: 'REJECTED',
        label: 'Rejected',
        aliases: <String>['Rejected'],
      ),
      FundraisingOptionItem(
        value: 'ARCHIVED',
        label: 'Archived',
        aliases: <String>['Archived'],
      ),
      FundraisingOptionItem(
        value: 'EXPIRED',
        label: 'Expired',
        aliases: <String>['Expired'],
      ),
    ];
