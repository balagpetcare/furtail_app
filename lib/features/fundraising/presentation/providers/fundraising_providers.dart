import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/analytics/analytics_provider.dart';

import 'package:furtail_app/services/api_client.dart';
import '../../data/models/fundraising_donation_models.dart';
import '../../data/models/fundraising_models.dart';
import '../../data/models/fundraising_payout_models.dart';
import '../../data/repositories/fundraising_repository.dart';
import '../../data/services/fundraising_donation_checkout_storage.dart';
import '../../data/services/fundraising_verification_recovery_service.dart';
import '../controllers/fundraising_donation_checkout_controller.dart';

// ---------------- Repository ----------------
final fundraisingRepositoryProvider = Provider<FundraisingRepository>((ref) {
  final client = ref.read(apiClientProvider);
  return FundraisingRepository(client);
});

final fundraisingDonationCheckoutStorageProvider =
    Provider<FundraisingDonationCheckoutStorage>((ref) {
      return FundraisingDonationCheckoutStorage();
    });

final fundraisingDonationCheckoutControllerProvider =
    ChangeNotifierProvider<FundraisingDonationCheckoutController>((ref) {
      return FundraisingDonationCheckoutController(
        repository: ref.read(fundraisingRepositoryProvider),
        storage: ref.read(fundraisingDonationCheckoutStorageProvider),
        analyticsService: ref.read(analyticsServiceProvider),
      );
    });

final fundraisingDonationHistoryProvider =
    Provider<List<FundraisingDonationCheckoutRecord>>((ref) {
      return ref.watch(
        fundraisingDonationCheckoutControllerProvider.select(
          (controller) => controller.history,
        ),
      );
    });

// ---------------- Feed Query State ----------------
enum FundraisingFeedView { publicFeed, myFundraisers }

enum FundraisingSort {
  newest('NEWEST'),
  oldest('OLDEST'),
  endingSoon('ENDING_SOON'),
  mostFunded('MOST_FUNDED');

  final String apiValue;
  const FundraisingSort(this.apiValue);
}

class FundraisingFeedQuery {
  final FundraisingFeedView view;
  final bool? verified;
  final String? category;
  final String? beneficiaryType;
  final String? urgency;
  final String? status;
  final String? location;
  final FundraisingSort sort;

  const FundraisingFeedQuery({
    this.view = FundraisingFeedView.publicFeed,
    this.verified,
    this.category,
    this.beneficiaryType,
    this.urgency,
    this.status,
    this.location,
    this.sort = FundraisingSort.endingSoon,
  });

  FundraisingFeedQuery copyWith({
    FundraisingFeedView? view,
    bool? verified,
    bool clearVerified = false,
    String? category,
    bool clearCategory = false,
    String? beneficiaryType,
    bool clearBeneficiaryType = false,
    String? urgency,
    bool clearUrgency = false,
    String? status,
    bool clearStatus = false,
    String? location,
    bool clearLocation = false,
    FundraisingSort? sort,
  }) {
    return FundraisingFeedQuery(
      view: view ?? this.view,
      verified: clearVerified ? null : (verified ?? this.verified),
      category: clearCategory ? null : (category ?? this.category),
      beneficiaryType: clearBeneficiaryType
          ? null
          : (beneficiaryType ?? this.beneficiaryType),
      urgency: clearUrgency ? null : (urgency ?? this.urgency),
      status: clearStatus ? null : (status ?? this.status),
      location: clearLocation ? null : (location ?? this.location),
      sort: sort ?? this.sort,
    );
  }
}

class FundraisingFeedQueryNotifier extends Notifier<FundraisingFeedQuery> {
  @override
  FundraisingFeedQuery build() => const FundraisingFeedQuery();

  void setView(FundraisingFeedView view) => state = state.copyWith(view: view);
  void setVerified(bool? v) =>
      state = state.copyWith(verified: v, clearVerified: v == null);
  void setCategory(String? v) =>
      state = state.copyWith(category: v, clearCategory: v == null);
  void setBeneficiaryType(String? v) => state = state.copyWith(
    beneficiaryType: v,
    clearBeneficiaryType: v == null,
  );
  void setUrgency(String? v) =>
      state = state.copyWith(urgency: v, clearUrgency: v == null);
  void setStatus(String? v) =>
      state = state.copyWith(status: v, clearStatus: v == null);
  void setLocation(String? v) =>
      state = state.copyWith(location: v, clearLocation: v == null);
  void setSort(FundraisingSort v) => state = state.copyWith(sort: v);

  void clearAll({bool preserveView = true}) => state = FundraisingFeedQuery(
    view: preserveView ? state.view : FundraisingFeedView.publicFeed,
  );
}

final fundraisingFeedQueryProvider =
    NotifierProvider<FundraisingFeedQueryNotifier, FundraisingFeedQuery>(
      FundraisingFeedQueryNotifier.new,
    );

final fundraisingFeedProvider =
    FutureProvider.autoDispose<List<FundraisingCampaign>>((ref) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      final q = ref.watch(fundraisingFeedQueryProvider);
      if (q.view == FundraisingFeedView.myFundraisers) {
        final page = await repo.fetchMyCampaignsPage(
          limit: 50,
          verified: q.verified,
          category: q.category,
          beneficiaryType: q.beneficiaryType,
          urgency: q.urgency,
          status: q.status,
          location: q.location,
          sort: q.sort.apiValue,
        );
        return page.items;
      }
      return repo.fetchFeed(
        limit: 50,
        verified: q.verified,
        category: q.category,
        beneficiaryType: q.beneficiaryType,
        urgency: q.urgency,
        status: q.status,
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
    FutureProvider.autoDispose<FundraisingAccount?>((ref) async {
      final repo = ref.read(fundraisingRepositoryProvider);
      return repo.fetchMyAccount();
    });

final fundraisingVerificationRecoveryServiceProvider =
    Provider<FundraisingVerificationRecoveryService>((ref) {
      return FundraisingVerificationRecoveryService();
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
