import 'package:bpa_app/core/network/api_endpoints.dart';
import 'package:bpa_app/services/api_client.dart';

import '../models/fundraising_models.dart';
import '../models/fundraising_payout_models.dart';

class FundraisingRepository {
  final ApiClient _api;
  FundraisingRepository(this._api);

  Future<List<FundraisingCampaign>> fetchFeed({
    int limit = 50,
    bool? verified,
    String? category,
    String? location,
    String? sort,
  }) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingFeed(
        limit: limit,
        verified: verified,
        category: category,
        location: location,
        sort: sort,
      ),
      auth: true,
    );
    final data = (res is Map && res['data'] is List) ? (res['data'] as List) : (res as List? ?? const []);
    return data
        .whereType<Map>()
        .map((e) => FundraisingCampaign.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ✅ Only campaigns created by the current user (for Unified Withdraw Hub).
  Future<List<FundraisingCampaign>> fetchMyCampaigns({int limit = 100}) async {
    final res = await _api.get(ApiEndpoints.fundraisingMyCampaigns(limit: limit), auth: true);
    final data = (res is Map && res['data'] is List) ? (res['data'] as List) : (res as List? ?? const []);
    return data
        .whereType<Map>()
        .map((e) => FundraisingCampaign.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<FundraisingCampaign> fetchCampaign(int id) async {
    final res = await _api.get(ApiEndpoints.fundraisingCampaign(id), auth: true);
    final data = (res is Map && res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : Map<String, dynamic>.from(res);
    return FundraisingCampaign.fromJson(data);
  }

  Future<void> donate({required int campaignId, required int amount}) async {
    await _api.post(ApiEndpoints.fundraisingDonate(campaignId), {'amount': amount}, auth: true);
  }

  Future<FundraisingCampaign> updateCampaign({
    required int campaignId,
    String? title,
    String? caption,
    String? category,
    String? locationText,
    int? targetAmount,
    DateTime? deadline,
    String? status,
    List<int>? mediaIds,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (caption != null) 'caption': caption,
      if (category != null) 'category': category,
      if (locationText != null) 'locationText': locationText,
      if (targetAmount != null) 'targetAmount': targetAmount,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
      if (status != null) 'status': status,
      if (mediaIds != null) 'mediaIds': mediaIds,
    };
    final res = await _api.patch(ApiEndpoints.fundraisingUpdateCampaign(campaignId), payload, auth: true);
    final data = (res is Map && res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : Map<String, dynamic>.from(res);
    return FundraisingCampaign.fromJson(data);
  }

  Future<void> deleteCampaign({required int campaignId}) async {
    await _api.delete(ApiEndpoints.fundraisingDeleteCampaign(campaignId), auth: true);
  }

  Future<List<DonationItem>> listDonations({required int campaignId, int limit = 50, int? cursor}) async {
    final res = await _api.get(ApiEndpoints.fundraisingCampaignDonations(campaignId, limit: limit, cursor: cursor), auth: true);
    final data = (res is Map && res['data'] is List) ? (res['data'] as List) : (res as List? ?? const []);
    return data.whereType<Map>().map((e) => DonationItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<FundraisingUpdateItem>> listUpdates({required int campaignId, int limit = 50, int? cursor}) async {
    final res = await _api.get(ApiEndpoints.fundraisingCampaignUpdates(campaignId, limit: limit, cursor: cursor), auth: true);
    final data = (res is Map && res['data'] is List) ? (res['data'] as List) : (res as List? ?? const []);
    return data.whereType<Map>().map((e) => FundraisingUpdateItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<FundraisingUpdateItem> createUpdate({
    required int campaignId,
    String? caption,
    List<int> mediaIds = const [],
  }) async {
    final payload = {
      'caption': caption,
      'mediaIds': mediaIds,
    };
    final res = await _api.post(ApiEndpoints.fundraisingCreateUpdate(campaignId), payload, auth: true);
    final data = (res is Map && res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : Map<String, dynamic>.from(res);
    return FundraisingUpdateItem.fromJson(data);
  }

  Future<FundraisingUpdateItem> updateUpdate({
    required int updateId,
    String? caption,
    List<int>? mediaIds,
  }) async {
    final payload = <String, dynamic>{
      if (caption != null) 'caption': caption,
      if (mediaIds != null) 'mediaIds': mediaIds,
    };
    final res = await _api.patch(ApiEndpoints.fundraisingUpdateUpdate(updateId), payload, auth: true);
    final data = (res is Map && res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : Map<String, dynamic>.from(res);
    return FundraisingUpdateItem.fromJson(data);
  }

  Future<void> deleteUpdate({required int updateId}) async {
    await _api.delete(ApiEndpoints.fundraisingDeleteUpdate(updateId), auth: true);
  }

  // ------------------ Fundraising account (verification) ------------------
  Future<FundraisingAccount> fetchMyAccount() async {
    final res = await _api.get(ApiEndpoints.fundraisingAccountMe(), auth: true);
    final data = (res is Map && res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'])
        : Map<String, dynamic>.from(res);
    return FundraisingAccount.fromJson(data);
  }

  Future<FundraisingAccount> updateMyAccount(Map<String, dynamic> payload) async {
    final res = await _api.patch(ApiEndpoints.fundraisingAccountUpdate(), payload, auth: true);
    final data = (res is Map && res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'])
        : Map<String, dynamic>.from(res);
    return FundraisingAccount.fromJson(data);
  }

  Future<void> submitMyAccount() async {
    await _api.post(ApiEndpoints.fundraisingAccountSubmit(), {}, auth: true);
  }

  Future<void> addDocument({required String title, required int mediaId}) async {
    await _api.post(ApiEndpoints.fundraisingAccountDocuments(), {
      'title': title,
      'mediaId': mediaId,
    }, auth: true);
  }

  Future<void> deleteDocument(int documentId) async {
    await _api.delete(ApiEndpoints.fundraisingAccountDocumentDelete(documentId), auth: true);
  }

  Future<FundraisingCampaign> createCampaign({
    required String title,
    required String caption,
    required String category,
    required String locationText,
    required int targetAmount,
    required DateTime deadline,
    List<int> mediaIds = const [],
  }) async {
    final payload = {
      'title': title,
      'caption': caption,
      'category': category,
      'locationText': locationText,
      'targetAmount': targetAmount,
      'deadline': deadline.toIso8601String(),
      'mediaIds': mediaIds,
    };

    final res = await _api.post(ApiEndpoints.fundraisingCreateCampaign(), payload, auth: true);
    final data = (res is Map && res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : Map<String, dynamic>.from(res);
    return FundraisingCampaign.fromJson(data);
  }

  // ------------------ Payout methods + Withdraw requests (Phase C) ------------------
  Future<List<PayoutCatalogItem>> listPayoutCatalog({bool all = false}) async {
    final res = await _api.get(ApiEndpoints.fundraisingPayoutCatalog(all: all), auth: true);
    final data = (res is Map && res['data'] is List) ? (res['data'] as List) : (res as List? ?? const []);
    return data.whereType<Map>().map((e) => PayoutCatalogItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<FundraisingPayoutMethod>> listMyPayoutMethods() async {
    final res = await _api.get(ApiEndpoints.fundraisingPayoutMethods(), auth: true);
    final data = (res is Map && res['data'] is List) ? (res['data'] as List) : (res as List? ?? const []);
    return data.whereType<Map>().map((e) => FundraisingPayoutMethod.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<FundraisingPayoutMethod> createMyPayoutMethod({
    required int catalogId,
    String? label,
    required Map<String, dynamic> detailsJson,
    bool isDefault = false,
  }) async {
    final payload = {
      'catalogId': catalogId,
      'label': label,
      'detailsJson': detailsJson,
      'isDefault': isDefault,
    };
    final res = await _api.post(ApiEndpoints.fundraisingPayoutMethods(), payload, auth: true);
    final data = (res is Map && res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'])
        : Map<String, dynamic>.from(res);
    return FundraisingPayoutMethod.fromJson(data);
  }

  Future<FundraisingPayoutMethod> updateMyPayoutMethod({
    required int id,
    String? label,
    Map<String, dynamic>? detailsJson,
    bool? isDefault,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      if (label != null) 'label': label,
      if (detailsJson != null) 'detailsJson': detailsJson,
      if (isDefault != null) 'isDefault': isDefault,
      if (isActive != null) 'isActive': isActive,
    };
    final res = await _api.patch(ApiEndpoints.fundraisingPayoutMethodUpdate(id), payload, auth: true);
    final data = (res is Map && res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'])
        : Map<String, dynamic>.from(res);
    return FundraisingPayoutMethod.fromJson(data);
  }

  Future<void> deleteMyPayoutMethod({required int id}) async {
    await _api.delete(ApiEndpoints.fundraisingPayoutMethodUpdate(id), auth: true);
  }

  Future<List<FundraisingWithdrawRequest>> listMyWithdrawRequests({
    int? campaignId,
    int limit = 50,
    int? cursor,
  }) async {
    final res = await _api.get(ApiEndpoints.fundraisingWithdrawRequests(campaignId: campaignId, limit: limit, cursor: cursor), auth: true);
    final data = (res is Map && res['data'] is List) ? (res['data'] as List) : (res as List? ?? const []);
    return data.whereType<Map>().map((e) => FundraisingWithdrawRequest.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<FundraisingWithdrawRequest> createWithdrawRequest({
    required int campaignId,
    required int amount,
    required int methodId,
    String? note,
  }) async {
    final payload = {
      'amount': amount,
      'methodId': methodId,
      'note': note,
    };
    final res = await _api.post(ApiEndpoints.fundraisingCreateWithdrawRequest(campaignId), payload, auth: true);
    final data = (res is Map && res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'])
        : Map<String, dynamic>.from(res);
    return FundraisingWithdrawRequest.fromJson(data);
  }
}
