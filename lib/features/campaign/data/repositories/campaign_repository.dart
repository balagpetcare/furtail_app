import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import '../../domain/vaccination_platform/campaign_analytics.dart';
import '../../domain/vaccination_platform/campaign_booking_flow.dart';
import '../../domain/vaccination_platform/campaign_ticket.dart';
import '../models/campaign_booking_draft.dart';
import '../models/campaign_countdown.dart';
import '../models/campaign_models.dart';
import '../models/campaign_public_models.dart';
import '../services/campaign_cache_service.dart';

class CampaignRepository {
  final ApiClient _api;
  final CampaignCacheService _cache;

  CampaignRepository(this._api, [CampaignCacheService? cache])
      : _cache = cache ?? CampaignCacheService();

  dynamic _data(dynamic res) {
    if (res is Map && res['data'] != null) return res['data'];
    return res;
  }

  // ---------------------------------------------------------------------------
  // Public discovery & booking
  // ---------------------------------------------------------------------------

  Future<List<PublicCampaign>> fetchPublicCampaigns({bool useCache = true}) async {
    try {
      final res = await _api.get(ApiEndpoints.campaignPublicCampaigns(), auth: false);
      final data = _data(res);
      if (data is! List) {
        if (useCache) {
          final cached = await _loadCachedHome();
          return cached;
        }
        return [];
      }
      var campaigns = data
          .whereType<Map>()
          .map((e) => PublicCampaign.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      campaigns = await _enrichWithUpcoming(campaigns);
      await _cache.saveHomeCampaigns(campaigns);
      return campaigns;
    } catch (_) {
      if (useCache) {
        final cached = await _loadCachedHome();
        if (cached.isNotEmpty) return cached;
      }
      rethrow;
    }
  }

  Future<List<PublicCampaign>> _loadCachedHome() async {
    return await _cache.loadHomeCampaigns() ?? [];
  }

  Future<List<PublicCampaign>> _enrichWithUpcoming(List<PublicCampaign> campaigns) async {
    try {
      final res = await _api.get(
        ApiEndpoints.campaignDiscoveryUpcoming(window: 'this_week'),
        auth: false,
      );
      final data = _data(res);
      if (data is! List) return campaigns;

      final metaBySlug = <String, UpcomingCampaignMeta>{};
      for (final row in data.whereType<Map>()) {
        final m = UpcomingCampaignMeta.fromJson(Map<String, dynamic>.from(row));
        metaBySlug[m.slug] = m;
      }

      return campaigns.map((c) {
        final meta = metaBySlug[c.slug];
        if (meta == null) return c;
        return c.copyWith(
          remainingSlots: meta.remainingCapacity,
          nextSlotDate: meta.nextSlotDate,
        );
      }).toList();
    } catch (_) {
      return campaigns;
    }
  }

  Future<PublicCampaign> fetchCampaignBySlug(String slug, {bool useCache = true}) async {
    try {
      final res = await _api.get(
        ApiEndpoints.campaignPublicCampaignBySlug(slug),
        auth: false,
      );
      final data = Map<String, dynamic>.from(_data(res) as Map);
      final campaign = PublicCampaign.fromJson(data);
      await _cache.saveCampaignDetail(campaign);
      return campaign;
    } catch (_) {
      if (useCache) {
        final cached = await _cache.loadCampaignDetail(slug);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  Future<CampaignCountdownSnapshot> fetchCampaignCountdown(String slug) async {
    final res = await _api.get(
      ApiEndpoints.campaignPublicCountdown(slug),
      auth: false,
    );
    final data = Map<String, dynamic>.from(_data(res) as Map);
    return CampaignCountdownSnapshot.fromJson(slug, data);
  }

  Future<Map<String, dynamic>> fetchLiveStats({String? slug}) async {
    final res = await _api.get(
      ApiEndpoints.campaignDiscoveryLiveStats(slug: slug),
      auth: false,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  Future<CampaignLiveAnalytics> fetchCampaignAnalytics({String? slug}) async {
    final raw = await fetchLiveStats(slug: slug);
    return CampaignLiveAnalytics.fromJson(raw);
  }

  Future<List<DhakaCityCorporation>> fetchDhakaCityCorporations() async {
    final res = await _api.get(ApiEndpoints.campaignDhakaCityCorporations(), auth: false);
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => DhakaCityCorporation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<DhakaBookingArea>> fetchDhakaBookingAreas(String corpCode) async {
    final res = await _api.get(
      ApiEndpoints.campaignDhakaBookingAreas(corpCode),
      auth: false,
    );
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => DhakaBookingArea.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CampaignTicket>> fetchBookingTickets(String bookingRef) async {
    final res = await _api.get(
      ApiEndpoints.campaignBookingTickets(bookingRef),
      auth: false,
    );
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => CampaignTicket.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<PublicCampaignLocation>> fetchCampaignLocations(String slug) async {
    final res = await _api.get(
      ApiEndpoints.campaignPublicLocations(slug),
      auth: false,
    );
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PublicCampaignLocation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<PublicCampaignSlot>> fetchLocationSlots({
    required int locationId,
    required String startDate,
    required String endDate,
  }) async {
    final res = await _api.get(
      ApiEndpoints.campaignPublicLocationSlots(
        locationId,
        startDate: startDate,
        endDate: endDate,
      ),
      auth: false,
    );
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PublicCampaignSlot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CheckoutInitResult> initCheckout({
    required CampaignBookingDraft draft,
    required String campaignSlug,
  }) async {
    final body = <String, dynamic>{
      'campaignSlug': campaignSlug,
      'phone': draft.phone,
      'catCount': draft.catCount,
      'returnUrl': 'furtail://campaign/checkout/success',
      'cancelUrl': 'furtail://campaign/checkout/failed',
    };
    if (draft.hasLocationSelection) {
      body['cityCorporationCode'] = draft.cityCorporationCode;
      body['bdAreaId'] = draft.bdAreaId;
      body['bookingArea'] = draft.bookingArea;
    } else if (draft.locationId != null) {
      body['locationId'] = draft.locationId;
      if (draft.slotId != null) body['slotId'] = draft.slotId;
    }
    if (draft.ownerName.isNotEmpty) body['ownerName'] = draft.ownerName;
    if (draft.alternatePhone.isNotEmpty) body['alternatePhone'] = draft.alternatePhone;
    if (draft.couponCode != null && draft.couponCode!.isNotEmpty) {
      body['couponCode'] = draft.couponCode;
    }
    if (draft.paymentMethod != null && draft.paymentMethod!.isNotEmpty) {
      body['paymentMethod'] = draft.paymentMethod;
    }

    final res = await _api.post(ApiEndpoints.campaignCheckoutInit(), body, auth: false);
    return CheckoutInitResult.fromJson(Map<String, dynamic>.from(_data(res) as Map));
  }

  Future<CheckoutInitResult> confirmFreeCheckout(String checkoutId) async {
    final res = await _api.post(
      ApiEndpoints.campaignCheckoutConfirmFree(),
      {'checkoutId': checkoutId},
      auth: false,
    );
    return CheckoutInitResult.fromJson(Map<String, dynamic>.from(_data(res) as Map));
  }

  Future<CheckoutStatusResult> getCheckoutStatus(String checkoutId) async {
    final res = await _api.get(
      ApiEndpoints.campaignCheckoutStatus(checkoutId),
      auth: false,
    );
    return CheckoutStatusResult.fromJson(Map<String, dynamic>.from(_data(res) as Map));
  }

  Future<bool> isHomeCacheStale() => _cache.isHomeCacheStale();

  // ---------------------------------------------------------------------------
  // Post-booking (campaign-link)
  // ---------------------------------------------------------------------------

  Future<CampaignLinkSummary> fetchSummary() async {
    final res = await _api.get(ApiEndpoints.campaignLinkSummary(), auth: true);
    final data = Map<String, dynamic>.from(_data(res) as Map);
    return CampaignLinkSummary.fromJson(data);
  }

  Future<List<CampaignBooking>> fetchMyBookings() async {
    final res = await _api.get(ApiEndpoints.campaignLinkMyBookings(), auth: true);
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => CampaignBooking.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<VaccinationRecord>> fetchVaccinations() async {
    final res = await _api.get(ApiEndpoints.campaignLinkVaccinations(), auth: true);
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => VaccinationRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<UpcomingVaccination>> fetchUpcoming() async {
    final res = await _api.get(ApiEndpoints.campaignLinkUpcoming(), auth: true);
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => UpcomingVaccination.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CampaignBenefits> fetchBenefits({String? slug}) async {
    final res = await _api.get(
      ApiEndpoints.campaignLinkBenefits(slug: slug),
      auth: true,
    );
    final data = Map<String, dynamic>.from(_data(res) as Map);
    return CampaignBenefits.fromJson(data);
  }

  Future<Map<String, dynamic>> importRecords() async {
    final res = await _api.post(ApiEndpoints.campaignLinkImport(), {}, auth: true);
    return Map<String, dynamic>.from(_data(res) as Map);
  }

  Future<void> linkPet({
    required int campaignPetId,
    required int existingPetId,
  }) async {
    await _api.post(
      ApiEndpoints.campaignLinkPet(campaignPetId),
      {'existingPetId': existingPetId},
      auth: true,
    );
  }

  Future<Map<String, dynamic>> claimCertificate(String token) async {
    final res = await _api.post(
      ApiEndpoints.campaignLinkClaimCertificate(token),
      {},
      auth: true,
    );
    return Map<String, dynamic>.from(_data(res) as Map);
  }

  Future<CertificateData> fetchCertificate(String token) async {
    final res = await _api.get(
      ApiEndpoints.campaignLinkCertificate(token),
      auth: true,
    );
    final data = Map<String, dynamic>.from(_data(res) as Map);
    return CertificateData.fromJson(data);
  }

  Future<CertificatePdfData?> fetchCertificatePdf(String token) async {
    try {
      final res = await _api.get(
        ApiEndpoints.campaignLinkCertificatePdf(token),
        auth: true,
      );
      final data = _data(res);
      if (data is! Map) return null;
      return CertificatePdfData.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> verifyCertificatePublic(String token) async {
    final res = await _api.get(
      ApiEndpoints.campaignPublicVerify(token),
      auth: false,
    );
    return Map<String, dynamic>.from(_data(res) as Map);
  }
}
