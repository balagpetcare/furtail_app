import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/vaccination_platform/campaign_analytics.dart';
import '../../domain/vaccination_platform/campaign_booking_flow.dart';
import '../../domain/vaccination_platform/campaign_ticket.dart';
import 'campaign_providers.dart';

final dhakaCityCorporationsProvider = FutureProvider<List<DhakaCityCorporation>>((ref) async {
  return ref.read(campaignRepositoryProvider).fetchDhakaCityCorporations();
});

final dhakaBookingAreasProvider =
    FutureProvider.family<List<DhakaBookingArea>, String>((ref, corpCode) async {
  if (corpCode.isEmpty) return const [];
  return ref.read(campaignRepositoryProvider).fetchDhakaBookingAreas(corpCode);
});

final campaignLiveAnalyticsProvider =
    FutureProvider.family<CampaignLiveAnalytics, String>((ref, slug) async {
  return ref.read(campaignRepositoryProvider).fetchCampaignAnalytics(slug: slug);
});

final bookingTicketsProvider =
    FutureProvider.family<List<CampaignTicket>, String>((ref, bookingRef) async {
  if (bookingRef.isEmpty) return const [];
  return ref.read(campaignRepositoryProvider).fetchBookingTickets(bookingRef);
});
