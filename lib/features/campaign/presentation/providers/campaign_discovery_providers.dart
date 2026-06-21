import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/campaign_booking_draft.dart';
import '../../data/models/campaign_public_models.dart';
import '../../data/services/campaign_cache_service.dart';
import 'campaign_providers.dart';
import 'smart_campaign_providers.dart';

final campaignCacheServiceProvider = Provider<CampaignCacheService>((ref) {
  return CampaignCacheService();
});

/// Home banner campaigns with cache + retry.
final homeCampaignsProvider =
    AsyncNotifierProvider<HomeCampaignsNotifier, HomeCampaignsState>(
  HomeCampaignsNotifier.new,
);

class HomeCampaignsState {
  final List<PublicCampaign> campaigns;
  final bool isStale;

  const HomeCampaignsState({
    this.campaigns = const [],
    this.isStale = false,
  });

  HomeCampaignsState copyWith({List<PublicCampaign>? campaigns, bool? isStale}) {
    return HomeCampaignsState(
      campaigns: campaigns ?? this.campaigns,
      isStale: isStale ?? this.isStale,
    );
  }
}

class HomeCampaignsNotifier extends AsyncNotifier<HomeCampaignsState> {
  @override
  Future<HomeCampaignsState> build() async {
    return _load(forceNetwork: false);
  }

  Future<HomeCampaignsState> _load({required bool forceNetwork}) async {
    final repo = ref.read(campaignRepositoryProvider);
    final cache = ref.read(campaignCacheServiceProvider);

    if (!forceNetwork) {
      final cached = await cache.loadHomeCampaigns();
      if (cached != null && cached.isNotEmpty) {
        final stale = await cache.isHomeCacheStale();
        // Refresh in background
        _refreshInBackground();
        return HomeCampaignsState(campaigns: cached, isStale: stale);
      }
    }

    try {
      final campaigns = await repo.fetchPublicCampaigns(useCache: !forceNetwork);
      final prepared = await ref.read(smartCampaignEngineProvider).prepareHomeCampaigns(campaigns);
      return HomeCampaignsState(campaigns: prepared, isStale: false);
    } catch (e) {
      final cached = await cache.loadHomeCampaigns();
      if (cached != null && cached.isNotEmpty) {
        return HomeCampaignsState(campaigns: cached, isStale: true);
      }
      rethrow;
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final repo = ref.read(campaignRepositoryProvider);
      final campaigns = await repo.fetchPublicCampaigns(useCache: false);
      final prepared = await ref.read(smartCampaignEngineProvider).prepareHomeCampaigns(campaigns);
      state = AsyncData(HomeCampaignsState(campaigns: prepared, isStale: false));
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load(forceNetwork: true));
  }
}

final campaignDetailProvider =
    FutureProvider.family<PublicCampaign, String>((ref, slug) async {
  return ref.read(campaignRepositoryProvider).fetchCampaignBySlug(slug);
});

final campaignLocationsProvider =
    FutureProvider.family<List<PublicCampaignLocation>, String>((ref, slug) async {
  return ref.read(campaignRepositoryProvider).fetchCampaignLocations(slug);
});

final campaignSlotsProvider = FutureProvider.family<
    List<PublicCampaignSlot>,
    ({int locationId, String startDate, String endDate})>((ref, args) async {
  return ref.read(campaignRepositoryProvider).fetchLocationSlots(
        locationId: args.locationId,
        startDate: args.startDate,
        endDate: args.endDate,
      );
});

final campaignBookingDraftProvider =
    StateNotifierProvider.family<CampaignBookingDraftNotifier, CampaignBookingDraft, String>(
  (ref, slug) => CampaignBookingDraftNotifier(slug),
);

class CampaignBookingDraftNotifier extends StateNotifier<CampaignBookingDraft> {
  CampaignBookingDraftNotifier(String slug)
      : super(CampaignBookingDraft(slug: slug));

  void update(CampaignBookingDraft draft) => state = draft;
  void nextStep() => state = state.copyWith(step: state.step + 1);
  void prevStep() => state = state.copyWith(step: state.step > 0 ? state.step - 1 : 0);
}

final campaignCheckoutProvider =
    AsyncNotifierProvider<CampaignCheckoutNotifier, CheckoutInitResult?>(
  CampaignCheckoutNotifier.new,
);

class CampaignCheckoutNotifier extends AsyncNotifier<CheckoutInitResult?> {
  @override
  Future<CheckoutInitResult?> build() async => null;

  Future<CheckoutInitResult> submit(CampaignBookingDraft draft) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(campaignRepositoryProvider).initCheckout(
            draft: draft,
            campaignSlug: draft.slug,
          );
      if (!result.requiresPayment) {
        final confirmed = await ref
            .read(campaignRepositoryProvider)
            .confirmFreeCheckout(result.checkoutId);
        state = AsyncData(confirmed);
        return confirmed;
      }
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<CheckoutStatusResult> pollStatus(String checkoutId) async {
    return ref.read(campaignRepositoryProvider).getCheckoutStatus(checkoutId);
  }
}
