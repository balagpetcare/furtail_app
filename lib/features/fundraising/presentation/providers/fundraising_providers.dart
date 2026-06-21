import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bpa_app/services/api_client.dart';
import '../../data/models/fundraising_models.dart';
import '../../data/models/fundraising_payout_models.dart';
import '../../data/repositories/fundraising_repository.dart';

// ---------------- Repository ----------------
final fundraisingRepositoryProvider = Provider<FundraisingRepository>((ref) {
  final client = ref.read(apiClientProvider);
  return FundraisingRepository(client);
});

// ---------------- Feed Query State ----------------
enum FundraisingSort {
  newCampaigns('NEW'),
  topDonated('TOP_DONATED'),
  endingSoon('ENDING_SOON');

  final String apiValue;
  const FundraisingSort(this.apiValue);
}

class FundraisingFeedQuery {
  final bool? verified;
  final String? category;
  final String? location;
  final FundraisingSort sort;

  const FundraisingFeedQuery({
    this.verified,
    this.category,
    this.location,
    this.sort = FundraisingSort.endingSoon,
  });

  FundraisingFeedQuery copyWith({
    bool? verified,
    bool clearVerified = false,
    String? category,
    bool clearCategory = false,
    String? location,
    bool clearLocation = false,
    FundraisingSort? sort,
  }) {
    return FundraisingFeedQuery(
      verified: clearVerified ? null : (verified ?? this.verified),
      category: clearCategory ? null : (category ?? this.category),
      location: clearLocation ? null : (location ?? this.location),
      sort: sort ?? this.sort,
    );
  }
}

class FundraisingFeedQueryNotifier extends Notifier<FundraisingFeedQuery> {
  @override
  FundraisingFeedQuery build() => const FundraisingFeedQuery();

  void setVerified(bool? v) =>
      state = state.copyWith(verified: v, clearVerified: v == null);
  void setCategory(String? v) =>
      state = state.copyWith(category: v, clearCategory: v == null);
  void setLocation(String? v) =>
      state = state.copyWith(location: v, clearLocation: v == null);
  void setSort(FundraisingSort v) => state = state.copyWith(sort: v);

  void clearAll() => state = const FundraisingFeedQuery();
}

final fundraisingFeedQueryProvider =
    NotifierProvider<FundraisingFeedQueryNotifier, FundraisingFeedQuery>(
      FundraisingFeedQueryNotifier.new,
    );

final fundraisingFeedProvider =
    FutureProvider.autoDispose<List<FundraisingCampaign>>((ref) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      final q = ref.watch(fundraisingFeedQueryProvider);
      return repo.fetchFeed(
        limit: 50,
        verified: q.verified,
        category: q.category,
        location: q.location,
        sort: q.sort.apiValue,
      );
    });

// ✅ My campaigns (for Unified Withdraw Hub)
final fundraisingMyCampaignsProvider =
    FutureProvider.autoDispose<List<FundraisingCampaign>>((ref) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      return repo.fetchMyCampaigns(limit: 100);
    });

final fundraisingCampaignProvider = FutureProvider.autoDispose
    .family<FundraisingCampaign, int>((ref, id) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      return repo.fetchCampaign(id);
    });

final fundraisingDonationsProvider = FutureProvider.autoDispose
    .family<List<DonationItem>, int>((ref, campaignId) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      return repo.listDonations(campaignId: campaignId, limit: 50);
    });

final fundraisingUpdatesProvider = FutureProvider.autoDispose
    .family<List<FundraisingUpdateItem>, int>((ref, campaignId) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      return repo.listUpdates(campaignId: campaignId, limit: 50);
    });

// ---------------- Account (verification profile) ----------------
final fundraisingMyAccountProvider =
    FutureProvider.autoDispose<FundraisingAccount>((ref) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      return repo.fetchMyAccount();
    });

// ---------------- Payout catalog + my methods (Phase C) ----------------
final fundraisingPayoutCatalogProvider =
    FutureProvider.autoDispose<List<PayoutCatalogItem>>((ref) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      return repo.listPayoutCatalog();
    });

final fundraisingMyPayoutMethodsProvider =
    FutureProvider.autoDispose<List<FundraisingPayoutMethod>>((ref) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      return repo.listMyPayoutMethods();
    });

final fundraisingWithdrawRequestsProvider = FutureProvider.autoDispose
    .family<List<FundraisingWithdrawRequest>, int?>((ref, campaignId) async {
  final repo = ref.read(fundraisingRepositoryProvider);
  return repo.listMyWithdrawRequests(campaignId: campaignId, limit: 50);
});
