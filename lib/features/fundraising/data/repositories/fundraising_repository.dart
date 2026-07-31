// ignore_for_file: use_null_aware_elements

import 'dart:math';

import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import '../fundraising_debug_logger.dart';
import '../models/fundraising_draft_models.dart';
import '../models/fundraising_donation_models.dart';
import '../models/fundraising_models.dart';
import '../models/fundraising_payout_models.dart';

class FundraisingPage<T> {
  const FundraisingPage({required this.items, required this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

class FundraisingRepository {
  final ApiClient _api;
  FundraisingRepository(this._api);

  Map<String, dynamic> _asMap(dynamic res) {
    if (res is Map && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    if (res is Map && !res.containsKey('data')) {
      return Map<String, dynamic>.from(res);
    }
    throw const FormatException(
      'Unexpected fundraising API response: object payload required.',
    );
  }

  List<dynamic> _asList(dynamic res) {
    if (res is Map && res['data'] is List) {
      return List<dynamic>.from(res['data'] as List);
    }
    if (res is Map && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final items = data['items'];
      if (items is List) return List<dynamic>.from(items);
    }
    if (res is Map && res['items'] is List) {
      return List<dynamic>.from(res['items'] as List);
    }
    if (res is List) return List<dynamic>.from(res);
    throw const FormatException(
      'Unexpected fundraising API response: list payload required.',
    );
  }

  List<Map<String, dynamic>> _asObjectList(dynamic res) {
    final values = _asList(res);
    if (values.any((value) => value is! Map)) {
      throw const FormatException(
        'Unexpected fundraising API response: object list required.',
      );
    }
    return values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
  }

  FundraisingPage<T> _asObjectPage<T>(
    dynamic res,
    T Function(Map<String, dynamic> json) parser,
  ) {
    final envelope = _asMap(res);
    final nextCursor = envelope['nextCursor']?.toString();
    final items = _asObjectList(res).map(parser).toList(growable: false);
    return FundraisingPage<T>(items: items, nextCursor: nextCursor);
  }

  bool _isAccountNotFoundError(Object error) {
    if (error is ApiClientException) {
      final code = (error.code ?? '').trim().toUpperCase();
      return (error.statusCode ?? 0) == 404 ||
          code.contains('NOT_FOUND') ||
          code.contains('ACCOUNT_NOT_FOUND') ||
          code.contains('FUNDRAISING_ACCOUNT_MISSING');
    }
    return false;
  }

  List<String> _topLevelKeys(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList();
      keys.sort();
      return keys;
    }
    if (value is ApiClientException) {
      return _topLevelKeys(value.responseData);
    }
    return const <String>[];
  }

  bool _looksLikeAccountMap(Map<String, dynamic> json) {
    return json.containsKey('id') && json.containsKey('status');
  }

  Map<String, dynamic>? _extractAccountPayload(
    dynamic res, {
    required String operation,
  }) {
    if (res == null) {
      return null;
    }

    if (res is String || res is List) {
      throw const FundraisingAccountParseException(
        'Unexpected fundraising account payload type.',
      );
    }

    if (res is! Map) {
      throw const FundraisingAccountParseException(
        'Unexpected fundraising account payload type.',
      );
    }

    final map = Map<String, dynamic>.from(res);
    final data = map['data'];

    if (data == null) {
      if (_looksLikeAccountMap(map)) {
        return map;
      }
      return null;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is String || data is List) {
      throw const FundraisingAccountParseException(
        'Unexpected fundraising account payload type.',
      );
    }

    if (_looksLikeAccountMap(map)) {
      return map;
    }

    throw const FundraisingAccountParseException(
      'Unexpected fundraising account payload type.',
    );
  }

  FundraisingAccount _parseAccountResponse(
    dynamic res, {
    required String operation,
  }) {
    try {
      final data = _extractAccountPayload(res, operation: operation);
      if (data == null) {
        throw const FundraisingAccountParseException(
          'Missing fundraising account payload.',
        );
      }
      return FundraisingAccount.fromJson(data);
    } on FundraisingAccountParseException catch (error) {
      logFundraisingRequestDebug(
        operation: operation,
        method: 'GET',
        endpointPath: ApiEndpoints.fundraisingAccountMe(),
        error: error,
        responseTopLevelKeys: _topLevelKeys(res),
      );
      rethrow;
    }
  }

  Future<List<FundraisingCampaign>> fetchFeed({
    int limit = 50,
    String? cursor,
    bool? verified,
    String? category,
    String? location,
    String? sort,
  }) async {
    final page = await fetchFeedPage(
      limit: limit,
      cursor: cursor,
      verified: verified,
      category: category,
      location: location,
      sort: sort,
    );
    return page.items;
  }

  Future<FundraisingPage<FundraisingCampaign>> fetchFeedPage({
    int limit = 50,
    String? cursor,
    bool? verified,
    String? category,
    String? location,
    String? sort,
  }) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingFeed(
        limit: limit,
        cursor: cursor,
        verified: verified,
        category: category,
        location: location,
        sort: sort,
      ),
      auth: true,
    );
    return _asObjectPage(res, FundraisingCampaign.fromJson);
  }

  // ✅ Only campaigns created by the current user (for Unified Withdraw Hub).
  Future<List<FundraisingCampaign>> fetchMyCampaigns({int limit = 100}) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingMyCampaigns(limit: limit),
      auth: true,
    );
    final data = _asObjectList(res);
    return data.map(FundraisingCampaign.fromJson).toList(growable: false);
  }

  Future<FundraisingCampaign> fetchCampaign(int id) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingCampaign(id),
      auth: true,
    );
    final data = _asMap(res);
    return FundraisingCampaign.fromJson(data);
  }

  Future<FundraisingDraftRecord> createDraft({
    required Map<String, dynamic> payload,
  }) async {
    final res = await _api.post(
      ApiEndpoints.fundraisingCreateDraft(),
      payload,
      auth: true,
    );
    return FundraisingDraftRecord.fromJson(_asMap(res));
  }

  Future<FundraisingDraftRecord> fetchDraft(String draftId) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingGetDraft(draftId),
      auth: true,
    );
    return FundraisingDraftRecord.fromJson(_asMap(res));
  }

  Future<FundraisingDraftRecord> updateDraft({
    required String draftId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _api.patch(
      ApiEndpoints.fundraisingUpdateDraft(draftId),
      payload,
      auth: true,
    );
    return FundraisingDraftRecord.fromJson(_asMap(res));
  }

  Future<FundraisingDraftRecord> submitDraft({
    required String draftId,
    required String idempotencyKey,
  }) async {
    final res = await _api.post(
      ApiEndpoints.fundraisingSubmitDraft(draftId),
      <String, dynamic>{'idempotencyKey': idempotencyKey},
      auth: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
    );
    return FundraisingDraftRecord.fromJson(_asMap(res));
  }

  Future<FundraisingDonationCheckoutResponse> createDonationCheckout({
    required int campaignId,
    required int amountMinor,
    required String idempotencyKey,
    required String returnUrl,
    required String cancelUrl,
    String currencyCode = 'BDT',
  }) async {
    final res = await _api.post(
      ApiEndpoints.fundraisingDonate(campaignId),
      <String, dynamic>{
        'amount': amountMinor,
        'currencyCode': currencyCode,
        'returnUrl': returnUrl,
        'cancelUrl': cancelUrl,
      },
      auth: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
    );
    return FundraisingDonationCheckoutResponse.fromJson(_asMap(res));
  }

  Future<FundraisingDonationCheckoutResponse> pollDonationCheckout({
    required int campaignId,
    required int amountMinor,
    required String idempotencyKey,
    required String returnUrl,
    required String cancelUrl,
    String currencyCode = 'BDT',
  }) {
    return createDonationCheckout(
      campaignId: campaignId,
      amountMinor: amountMinor,
      idempotencyKey: idempotencyKey,
      returnUrl: returnUrl,
      cancelUrl: cancelUrl,
      currencyCode: currencyCode,
    );
  }

  Future<FundraisingCampaign> updateCampaign({
    required int campaignId,
    String? title,
    String? caption,
    String? category,
    String? locationText,
    int? targetAmount,
    int? targetAmountMinor,
    int? monthlyGoalMinor,
    String? fundingMode,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? deadline,
    DateTime? nextReviewAt,
    String? status,
    List<int>? mediaIds,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (caption != null) 'caption': caption,
      if (category != null) 'category': category,
      if (locationText != null) 'locationText': locationText,
      if (targetAmount != null) 'targetAmount': targetAmount,
      if (targetAmountMinor != null) 'targetAmountMinor': targetAmountMinor,
      if (monthlyGoalMinor != null) 'monthlyGoalMinor': monthlyGoalMinor,
      if (fundingMode != null) 'fundingMode': fundingMode,
      if (startsAt != null) 'startsAt': startsAt.toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
      if (deadline != null) 'deadline': deadline.toIso8601String(),
      if (nextReviewAt != null) 'nextReviewAt': nextReviewAt.toIso8601String(),
      if (status != null) 'status': status,
      if (mediaIds != null) 'mediaIds': mediaIds,
    };
    final res = await _api.patch(
      ApiEndpoints.fundraisingUpdateCampaign(campaignId),
      payload,
      auth: true,
    );
    final data = _asMap(res);
    return FundraisingCampaign.fromJson(data);
  }

  Future<void> deleteCampaign({required int campaignId}) async {
    await _api.delete(
      ApiEndpoints.fundraisingDeleteCampaign(campaignId),
      auth: true,
    );
  }

  Future<List<DonationItem>> listDonations({
    required int campaignId,
    int limit = 50,
    String? cursor,
  }) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingCampaignDonations(
        campaignId,
        limit: limit,
        cursor: cursor,
      ),
      auth: true,
    );
    final data = _asObjectList(res);
    return data.map(DonationItem.fromJson).toList(growable: false);
  }

  Future<List<FundraisingUpdateItem>> listUpdates({
    required int campaignId,
    int limit = 50,
    String? cursor,
  }) async {
    final page = await listUpdatesPage(
      campaignId: campaignId,
      limit: limit,
      cursor: cursor,
    );
    return page.items;
  }

  Future<FundraisingPage<FundraisingUpdateItem>> listUpdatesPage({
    required int campaignId,
    int limit = 50,
    String? cursor,
  }) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingCampaignUpdates(
        campaignId,
        limit: limit,
        cursor: cursor,
      ),
      auth: true,
    );
    return _asObjectPage(res, FundraisingUpdateItem.fromJson);
  }

  Future<FundraisingUpdateItem> createUpdate({
    required int campaignId,
    String? caption,
    List<int> mediaIds = const [],
  }) async {
    final payload = {'caption': caption, 'mediaIds': mediaIds};
    final res = await _api.post(
      ApiEndpoints.fundraisingCreateUpdate(campaignId),
      payload,
      auth: true,
    );
    final data = _asMap(res);
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
    final res = await _api.patch(
      ApiEndpoints.fundraisingUpdateUpdate(updateId),
      payload,
      auth: true,
    );
    final data = _asMap(res);
    return FundraisingUpdateItem.fromJson(data);
  }

  Future<void> deleteUpdate({required int updateId}) async {
    await _api.delete(
      ApiEndpoints.fundraisingDeleteUpdate(updateId),
      auth: true,
    );
  }

  // ------------------ Fundraising account (verification) ------------------
  Future<FundraisingAccount?> fetchMyAccount() async {
    List<String> responseTopLevelKeys = const <String>[];
    try {
      final res = await _api.get(
        ApiEndpoints.fundraisingAccountMe(),
        auth: true,
      );
      responseTopLevelKeys = _topLevelKeys(res);
      final payload = _extractAccountPayload(
        res,
        operation: 'fundraising.account.fetchMyAccount',
      );
      if (payload == null) return null;
      return FundraisingAccount.fromJson(payload);
    } catch (error) {
      if (_isAccountNotFoundError(error)) {
        return null;
      }
      if (error is FundraisingAccountParseException) {
        logFundraisingRequestDebug(
          operation: 'fundraising.account.fetchMyAccount',
          method: 'GET',
          endpointPath: ApiEndpoints.fundraisingAccountMe(),
          error: error,
          responseTopLevelKeys: responseTopLevelKeys,
        );
        rethrow;
      }
      logFundraisingRequestDebug(
        operation: 'fundraising.account.fetchMyAccount',
        method: 'GET',
        endpointPath: ApiEndpoints.fundraisingAccountMe(),
        error: error,
        responseTopLevelKeys: responseTopLevelKeys,
      );
      rethrow;
    }
  }

  Future<FundraisingAccount> updateMyAccount(
    Map<String, dynamic> payload,
  ) async {
    List<String> responseTopLevelKeys = const <String>[];
    try {
      final res = await _api.patch(
        ApiEndpoints.fundraisingAccountUpdate(),
        payload,
        auth: true,
      );
      responseTopLevelKeys = _topLevelKeys(res);
      return _parseAccountResponse(
        res,
        operation: 'fundraising.account.updateMyAccount',
      );
    } catch (error) {
      if (error is FundraisingAccountParseException) {
        logFundraisingRequestDebug(
          operation: 'fundraising.account.updateMyAccount',
          method: 'PATCH',
          endpointPath: ApiEndpoints.fundraisingAccountUpdate(),
          error: error,
          responseTopLevelKeys: responseTopLevelKeys,
        );
        rethrow;
      }
      if (error is ApiClientException) {
        logFundraisingRequestDebug(
          operation: 'fundraising.account.updateMyAccount',
          method: 'PATCH',
          endpointPath: ApiEndpoints.fundraisingAccountUpdate(),
          error: error,
          responseTopLevelKeys: responseTopLevelKeys,
        );
        rethrow;
      }
      logFundraisingRequestDebug(
        operation: 'fundraising.account.updateMyAccount',
        method: 'PATCH',
        endpointPath: ApiEndpoints.fundraisingAccountUpdate(),
        error: error,
        responseTopLevelKeys: responseTopLevelKeys,
      );
      rethrow;
    }
  }

  Future<void> submitMyAccount() async {
    try {
      await _api.post(ApiEndpoints.fundraisingAccountSubmit(), {}, auth: true);
    } catch (error) {
      logFundraisingRequestDebug(
        operation: 'fundraising.account.submitMyAccount',
        method: 'POST',
        endpointPath: ApiEndpoints.fundraisingAccountSubmit(),
        error: error,
      );
      rethrow;
    }
  }

  Future<void> addDocument({
    required String title,
    required int mediaId,
    String documentType = 'SUPPORTING',
  }) async {
    await _api.post(ApiEndpoints.fundraisingAccountDocuments(), {
      'title': title,
      'mediaId': mediaId,
      'documentType': documentType,
    }, auth: true);
  }

  Future<void> deleteDocument(int documentId) async {
    await _api.delete(
      ApiEndpoints.fundraisingAccountDocumentDelete(documentId),
      auth: true,
    );
  }

  Future<FundraisingCampaign> createCampaign({
    required String title,
    required String caption,
    required String category,
    required String locationText,
    int? targetAmount,
    int? targetAmountMinor,
    int? monthlyGoalMinor,
    String fundingMode = 'ONE_TIME',
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? deadline,
    DateTime? nextReviewAt,
    List<int> mediaIds = const [],
  }) async {
    final payload = {
      'title': title,
      'caption': caption,
      'category': category,
      'locationText': locationText,
      if (targetAmount != null) 'targetAmount': targetAmount,
      if (targetAmountMinor != null) 'targetAmountMinor': targetAmountMinor,
      if (monthlyGoalMinor != null) 'monthlyGoalMinor': monthlyGoalMinor,
      'fundingMode': fundingMode,
      if (startsAt != null) 'startsAt': startsAt.toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
      if (deadline != null) 'deadline': deadline.toIso8601String(),
      if (nextReviewAt != null) 'nextReviewAt': nextReviewAt.toIso8601String(),
      'mediaIds': mediaIds,
    };

    final res = await _api.post(
      ApiEndpoints.fundraisingCreateCampaign(),
      payload,
      auth: true,
    );
    final data = _asMap(res);
    return FundraisingCampaign.fromJson(data);
  }

  // ------------------ Payout methods + Withdraw requests (Phase C) ------------------
  Future<List<PayoutCatalogItem>> listPayoutCatalog({bool all = false}) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingPayoutCatalog(all: all),
      auth: true,
    );
    final data = _asObjectList(res);
    return data.map(PayoutCatalogItem.fromJson).toList(growable: false);
  }

  Future<List<FundraisingPayoutMethod>> listMyPayoutMethods() async {
    final res = await _api.get(
      ApiEndpoints.fundraisingPayoutMethods(),
      auth: true,
    );
    final data = _asObjectList(res);
    return data.map(FundraisingPayoutMethod.fromJson).toList(growable: false);
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
    final res = await _api.post(
      ApiEndpoints.fundraisingPayoutMethods(),
      payload,
      auth: true,
    );
    final data = _asMap(res);
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
    final res = await _api.patch(
      ApiEndpoints.fundraisingPayoutMethodUpdate(id),
      payload,
      auth: true,
    );
    final data = _asMap(res);
    return FundraisingPayoutMethod.fromJson(data);
  }

  Future<void> deleteMyPayoutMethod({required int id}) async {
    await _api.delete(
      ApiEndpoints.fundraisingPayoutMethodUpdate(id),
      auth: true,
    );
  }

  Future<List<FundraisingWithdrawRequest>> listMyWithdrawRequests({
    int? campaignId,
    String? status,
    int limit = 50,
    int? cursor,
  }) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingWithdrawRequests(
        campaignId: campaignId,
        status: status,
        limit: limit,
        cursor: cursor,
      ),
      auth: true,
    );
    final data = _asObjectList(res);
    return data
        .map(FundraisingWithdrawRequest.fromJson)
        .toList(growable: false);
  }

  Future<FundraisingWithdrawBalanceSummary> fetchWithdrawBalanceSummary({
    required int campaignId,
  }) async {
    final res = await _api.get(
      ApiEndpoints.fundraisingWithdrawBalanceSummary(campaignId),
      auth: true,
    );
    final data = _asMap(res);
    return FundraisingWithdrawBalanceSummary.fromJson(data);
  }

  Future<FundraisingWithdrawRequest> createWithdrawRequest({
    required int campaignId,
    required int amount,
    required int methodId,
    String? note,
  }) async {
    final payload = {'amount': amount, 'methodId': methodId, 'note': note};
    final res = await _api.post(
      ApiEndpoints.fundraisingCreateWithdrawRequest(campaignId),
      payload,
      auth: true,
      headers: {
        'Idempotency-Key':
            'fundraising-withdraw-$campaignId-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 31)}',
      },
    );
    final data = _asMap(res);
    return FundraisingWithdrawRequest.fromJson(data);
  }
}
