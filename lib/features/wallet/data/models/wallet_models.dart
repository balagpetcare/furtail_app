class WalletSummary {
  final int id;
  final String currency;
  final String balance;
  final String availableBalance;
  final String pendingBalance;
  final String lockedBalance;

  const WalletSummary({
    required this.id,
    required this.currency,
    required this.balance,
    required this.availableBalance,
    required this.pendingBalance,
    required this.lockedBalance,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> j) {
    return WalletSummary(
      id: (j['id'] as num).toInt(),
      currency: (j['currency'] ?? 'BDT').toString(),
      balance: (j['balance'] ?? '0.00').toString(),
      availableBalance: (j['availableBalance'] ?? '0.00').toString(),
      pendingBalance: (j['pendingBalance'] ?? '0.00').toString(),
      lockedBalance: (j['lockedBalance'] ?? '0.00').toString(),
    );
  }
}

class WalletTransactionItem {
  final int id;
  final String type; // CREDIT/DEBIT
  final String status; // PENDING/SUCCESS/FAILED
  final String amount;
  final String? sourceType;
  final int? sourceId;
  final String? note;
  final String createdAt;

  const WalletTransactionItem({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.sourceType,
    required this.sourceId,
    required this.note,
    required this.createdAt,
  });

  factory WalletTransactionItem.fromJson(Map<String, dynamic> j) {
    return WalletTransactionItem(
      id: (j['id'] as num).toInt(),
      type: (j['type'] ?? 'CREDIT').toString(),
      status: (j['status'] ?? 'PENDING').toString(),
      amount: (j['amount'] ?? '0.00').toString(),
      sourceType: j['sourceType']?.toString(),
      sourceId: (j['sourceId'] is num) ? (j['sourceId'] as num).toInt() : null,
      note: j['note']?.toString(),
      createdAt: (j['createdAt'] ?? '').toString(),
    );
  }
}


class WalletWithdrawRequest {
  final int id;
  final String amount;
  final String method;
  final String status;
  final String createdAt;

  const WalletWithdrawRequest({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
  });

  factory WalletWithdrawRequest.fromJson(Map<String, dynamic> j) {
    return WalletWithdrawRequest(
      id: (j['id'] as num).toInt(),
      amount: (j['amount'] ?? '0.00').toString(),
      method: (j['method'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      createdAt: (j['createdAt'] ?? '').toString(),
    );
  }
}
