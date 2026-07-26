import '../services/fundraising_json.dart';

class PayoutCatalogItem {
  final int id;
  final String name;
  final String type;
  final bool isActive;

  const PayoutCatalogItem({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory PayoutCatalogItem.fromJson(Map<String, dynamic> json) {
    return PayoutCatalogItem(
      id: fundraisingInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }
}

class FundraisingPayoutMethod {
  final int id;
  final int catalogId;
  final String? label;
  final Map<String, dynamic> detailsJson;
  final String maskedSummary;
  final bool isDefault;
  final bool isActive;
  final PayoutCatalogItem? catalog;

  const FundraisingPayoutMethod({
    required this.id,
    required this.catalogId,
    required this.label,
    required this.detailsJson,
    required this.maskedSummary,
    required this.isDefault,
    required this.isActive,
    this.catalog,
  });

  factory FundraisingPayoutMethod.fromJson(Map<String, dynamic> json) {
    return FundraisingPayoutMethod(
      id: fundraisingInt(json['id']) ?? 0,
      catalogId: fundraisingInt(json['catalogId']) ?? 0,
      label: json['label']?.toString(),
      detailsJson: (json['detailsJson'] is Map)
          ? Map<String, dynamic>.from(json['detailsJson'])
          : <String, dynamic>{},
      maskedSummary: (json['maskedSummary'] ?? '').toString(),
      isDefault: (json['isDefault'] as bool?) ?? false,
      isActive: (json['isActive'] as bool?) ?? true,
      catalog: (json['catalog'] is Map)
          ? PayoutCatalogItem.fromJson(
              Map<String, dynamic>.from(json['catalog']),
            )
          : null,
    );
  }

  String get displayName {
    final catalogName = catalog?.name ?? '';
    final trimmedLabel = (label ?? '').trim();
    if (trimmedLabel.isEmpty) return catalogName;
    if (catalogName.isEmpty) return trimmedLabel;
    return '$catalogName • $trimmedLabel';
  }

  String get summary {
    if (maskedSummary.trim().isNotEmpty) return maskedSummary;
    final typeUpper = (catalog?.type ?? '').toUpperCase();
    if (typeUpper == 'MFS') {
      final number =
          (detailsJson['walletNumber'] ??
                  detailsJson['number'] ??
                  detailsJson['last4'] ??
                  '')
              .toString();
      return number.isEmpty
          ? 'Mobile wallet'
          : 'Wallet ending ${number.substring(number.length - 4)}';
    }
    if (typeUpper == 'BANK') {
      final account =
          (detailsJson['accountNumber'] ?? detailsJson['last4'] ?? '')
              .toString();
      final bank = (detailsJson['bankName'] ?? '').toString();
      final name = bank.isEmpty ? 'Bank account' : bank;
      return account.isEmpty
          ? name
          : '$name ending ${account.substring(account.length - 4)}';
    }
    return 'Payout method on file';
  }
}

class FundraisingWithdrawBalanceSummary {
  final String currencyCode;
  final int totalRaisedMinor;
  final int pendingMinor;
  final int availableMinor;
  final int reservedMinor;
  final int transferredMinor;

  const FundraisingWithdrawBalanceSummary({
    required this.currencyCode,
    required this.totalRaisedMinor,
    required this.pendingMinor,
    required this.availableMinor,
    required this.reservedMinor,
    required this.transferredMinor,
  });

  factory FundraisingWithdrawBalanceSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return FundraisingWithdrawBalanceSummary(
      currencyCode: (json['currencyCode'] ?? 'BDT').toString(),
      totalRaisedMinor: fundraisingInt(json['totalRaisedMinor']) ?? 0,
      pendingMinor: fundraisingInt(json['pendingMinor']) ?? 0,
      availableMinor: fundraisingInt(json['availableMinor']) ?? 0,
      reservedMinor: fundraisingInt(json['reservedMinor']) ?? 0,
      transferredMinor: fundraisingInt(json['transferredMinor']) ?? 0,
    );
  }
}

class FundraisingWithdrawTimelineEntry {
  final String status;
  final DateTime? at;
  final String? reason;

  const FundraisingWithdrawTimelineEntry({
    required this.status,
    required this.at,
    required this.reason,
  });

  factory FundraisingWithdrawTimelineEntry.fromJson(Map<String, dynamic> json) {
    final rawAt = json['at']?.toString();
    return FundraisingWithdrawTimelineEntry(
      status: (json['status'] ?? '').toString(),
      at: rawAt == null || rawAt.isEmpty ? null : DateTime.tryParse(rawAt),
      reason: json['reason']?.toString(),
    );
  }
}

class FundraisingWithdrawRequest {
  final int id;
  final int campaignId;
  final int amount;
  final String status;
  final String? note;
  final String? failureReason;
  final DateTime createdAt;
  final FundraisingPayoutMethod? method;
  final FundraisingWithdrawBalanceSummary? balanceSummary;
  final List<FundraisingWithdrawTimelineEntry> timeline;

  const FundraisingWithdrawRequest({
    required this.id,
    required this.campaignId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.note,
    this.failureReason,
    this.method,
    this.balanceSummary,
    this.timeline = const <FundraisingWithdrawTimelineEntry>[],
  });

  factory FundraisingWithdrawRequest.fromJson(Map<String, dynamic> json) {
    final timelineRaw = (json['timeline'] as List?) ?? const [];
    return FundraisingWithdrawRequest(
      id: fundraisingInt(json['id']) ?? 0,
      campaignId: fundraisingInt(json['campaignId']) ?? 0,
      amount: fundraisingInt(json['amount']) ?? 0,
      status: (json['status'] ?? '').toString(),
      note: json['note']?.toString(),
      failureReason: json['failureReason']?.toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      method: (json['method'] is Map)
          ? FundraisingPayoutMethod.fromJson(
              Map<String, dynamic>.from(json['method']),
            )
          : null,
      balanceSummary: (json['balanceSummary'] is Map)
          ? FundraisingWithdrawBalanceSummary.fromJson(
              Map<String, dynamic>.from(json['balanceSummary']),
            )
          : null,
      timeline: timelineRaw
          .whereType<Map>()
          .map(
            (entry) => FundraisingWithdrawTimelineEntry.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList(),
    );
  }
}
