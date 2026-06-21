import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import '../models/wallet_models.dart';

class WalletRepository {
  final ApiClient _api;
  WalletRepository(this._api);

  Future<WalletSummary> fetchMyWallet() async {
    final res = await _api.get(ApiEndpoints.walletMe(), auth: true);
    final data = (res is Map && res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'] as Map)
        : Map<String, dynamic>.from(res as Map);
    return WalletSummary.fromJson(data);
  }

  Future<List<WalletTransactionItem>> listTransactions({
    int limit = 20,
    int? cursor,
  }) async {
    final res = await _api.get(
      ApiEndpoints.walletTransactions(limit: limit, cursor: cursor),
      auth: true,
    );
    final data = (res is Map && res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'] as Map)
        : Map<String, dynamic>.from(res as Map);
    final items = (data['items'] is List) ? (data['items'] as List) : const [];
    return items
        .whereType<Map>()
        .map(
          (e) => WalletTransactionItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  // -----------------------------
  // Wallet Withdraw (V2/V3)
  // -----------------------------

  Future<List<WalletWithdrawRequest>> listWithdrawRequests({
    int limit = 20,
    int? cursor,
    String? status,
  }) async {
    final res = await _api.get(
      ApiEndpoints.walletWithdrawRequests(
        limit: limit,
        cursor: cursor,
        status: status,
      ),
      auth: true,
    );
    final data = (res is Map && res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'] as Map)
        : Map<String, dynamic>.from(res as Map);
    final items = (data['items'] is List) ? (data['items'] as List) : const [];
    return items
        .whereType<Map>()
        .map(
          (e) => WalletWithdrawRequest.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<void> createWithdrawRequest({
    required int amount,
    required String method,
    required Map<String, dynamic> payoutDetails,
    String? note,
  }) async {
    await _api.post(ApiEndpoints.walletWithdrawCreate(), {
      'amount': amount,
      'method': method,
      'payoutDetails': payoutDetails,
      if (note != null) 'note': note,
    }, auth: true);
  }

  Future<void> cancelWithdrawRequest(int id) async {
    await _api.patch(
      ApiEndpoints.walletWithdrawCancel(id),
      {}, // ✅ patch() তোমার ক্লায়েন্টে 2nd argument required
      auth: true,
    );
  }
}
