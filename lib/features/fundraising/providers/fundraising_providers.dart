import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fundraising_models.dart';
import '../services/fundraising_api.dart';

/// Provide these from your app's DI:
final fundraisingApiProvider = Provider<FundraisingApi>((ref) {
  throw UnimplementedError('Provide FundraisingApi via overrides');
});

final fundraisingCampaignProvider =
    FutureProvider.family<FundraisingCampaign, int>((ref, id) async {
      final api = ref.watch(fundraisingApiProvider);
      return api.getCampaign(id);
    });

final fundraisingDonationsProvider =
    FutureProvider.family<List<DonationItem>, int>((ref, campaignId) async {
      final api = ref.watch(fundraisingApiProvider);
      return api.listDonations(campaignId);
    });

final fundraisingUpdatesProvider =
    FutureProvider.family<List<FundraisingUpdateItem>, int>((
      ref,
      campaignId,
    ) async {
      final api = ref.watch(fundraisingApiProvider);
      return api.listUpdates(campaignId);
    });
