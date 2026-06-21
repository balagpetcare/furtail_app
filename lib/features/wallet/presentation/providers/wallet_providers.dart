import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bpa_app/services/api_client.dart';

import '../../data/repositories/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return WalletRepository(api);
});

final walletSummaryProvider = FutureProvider((ref) async {
  final repo = ref.read(walletRepositoryProvider);
  return repo.fetchMyWallet();
});

final walletTransactionsProvider = FutureProvider((ref) async {
  final repo = ref.read(walletRepositoryProvider);
  return repo.listTransactions(limit: 20);
});


final walletWithdrawRequestsProvider = FutureProvider((ref) async {
  final repo = ref.read(walletRepositoryProvider);
  return repo.listWithdrawRequests(limit: 50);
});
