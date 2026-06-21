class PayoutCatalogItem {
  final int id;
  final String name;
  final String type; // MFS | BANK
  final bool isActive;

  const PayoutCatalogItem({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory PayoutCatalogItem.fromJson(Map<String, dynamic> json) {
    return PayoutCatalogItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
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
  final bool isDefault;
  final bool isActive;
  final PayoutCatalogItem? catalog;

  const FundraisingPayoutMethod({
    required this.id,
    required this.catalogId,
    required this.label,
    required this.detailsJson,
    required this.isDefault,
    required this.isActive,
    this.catalog,
  });

  factory FundraisingPayoutMethod.fromJson(Map<String, dynamic> json) {
    return FundraisingPayoutMethod(
      id: (json['id'] as num?)?.toInt() ?? 0,
      catalogId: (json['catalogId'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString(),
      detailsJson: (json['detailsJson'] is Map)
          ? Map<String, dynamic>.from(json['detailsJson'])
          : <String, dynamic>{},
      isDefault: (json['isDefault'] as bool?) ?? false,
      isActive: (json['isActive'] as bool?) ?? true,
      catalog: (json['catalog'] is Map)
          ? PayoutCatalogItem.fromJson(Map<String, dynamic>.from(json['catalog']))
          : null,
    );
  }

  String get displayName {
    final c = catalog?.name ?? '';
    final l = (label ?? '').trim();
    if (l.isEmpty) return c;
    if (c.isEmpty) return l;
    return '$c • $l';
  }

  String get summary {
    final t = (catalog?.type ?? '').toUpperCase();
    if (t == 'MFS') {
      final n = (detailsJson['walletNumber'] ?? detailsJson['number'] ?? '').toString();
      return n.isEmpty ? 'Mobile wallet' : 'Wallet: $n';
    }
    if (t == 'BANK') {
      final acc = (detailsJson['accountNumber'] ?? '').toString();
      final bank = (detailsJson['bankName'] ?? '').toString();
      final s1 = bank.isEmpty ? 'Bank' : bank;
      return acc.isEmpty ? s1 : '$s1 • A/C: $acc';
    }
    return 'Payout method';
  }
}

class FundraisingWithdrawRequest {
  final int id;
  final int campaignId;
  final int amount;
  final String status;
  final String? note;
  final DateTime createdAt;
  final FundraisingPayoutMethod? method;

  const FundraisingWithdrawRequest({
    required this.id,
    required this.campaignId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.note,
    this.method,
  });

  factory FundraisingWithdrawRequest.fromJson(Map<String, dynamic> json) {
    return FundraisingWithdrawRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      campaignId: (json['campaignId'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '').toString(),
      note: json['note']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      method: (json['method'] is Map)
          ? FundraisingPayoutMethod.fromJson(Map<String, dynamic>.from(json['method']))
          : null,
    );
  }
}
