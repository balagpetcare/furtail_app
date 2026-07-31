import 'dart:convert';

import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_date_serializer.dart';

import '../services/fundraising_json.dart';

enum FundraisingWizardStep {
  fundraiserType,
  storyAndGoal,
  caseDetails,
  location,
  evidence,
  payoutReadiness,
  preview,
}

const int kFundraisingWizardStepCount = 6;

enum FundraisingWizardErrorType {
  validation,
  timeout,
  offline,
  sessionExpired,
  verificationRejected,
  mediaFailure,
  saveFailed,
  submitFailed,
  unknown,
}

class FundraisingWizardFailure {
  const FundraisingWizardFailure({
    required this.type,
    this.apiCode,
    this.message,
  });

  final FundraisingWizardErrorType type;
  final String? apiCode;
  final String? message;
}

class FundraisingExpenseItem {
  const FundraisingExpenseItem({
    required this.code,
    required this.label,
    this.amountMinor,
  });

  final String code;
  final String label;
  final int? amountMinor;

  FundraisingExpenseItem copyWith({
    String? code,
    String? label,
    int? amountMinor,
    bool clearAmountMinor = false,
  }) {
    return FundraisingExpenseItem(
      code: code ?? this.code,
      label: label ?? this.label,
      amountMinor: clearAmountMinor ? null : (amountMinor ?? this.amountMinor),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'label': label,
      'amountMinor': amountMinor,
    };
  }

  factory FundraisingExpenseItem.fromJson(Map<String, dynamic> json) {
    return FundraisingExpenseItem(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      amountMinor: fundraisingInt(json['amountMinor']),
    );
  }
}

class FundraisingDraftRecord {
  const FundraisingDraftRecord({
    required this.id,
    required this.status,
    this.publicId,
    this.slug,
    this.title,
    this.caption,
    this.category,
    this.fundingMode = 'ONE_TIME',
    this.currencyCode = 'BDT',
    this.targetAmountMinor,
    this.monthlyGoalMinor,
    this.campaignDurationDays,
    this.startsAt,
    this.endsAt,
    this.deadline,
    this.nextReviewAt,
    this.beneficiaryType,
    this.beneficiaryName,
    this.petId,
    this.urgency,
    this.treatmentProvider,
    this.estimatedExpenseMinor,
    this.spendingPlan,
    this.locationText,
    this.countryId,
    this.stateId,
    this.cityId,
    this.subDistrictId,
    this.bdAddressMode,
    this.bdDivisionId,
    this.bdDistrictId,
    this.bdCityCorporationId,
    this.bdZoneId,
    this.bdWardId,
    this.bdUpazilaId,
    this.bdUnionId,
    this.bdAreaId,
    this.submittedAt,
    this.mediaIds = const <int>[],
    this.mediaUrls = const <String>[],
  });

  final int id;
  final String status;
  final String? publicId;
  final String? slug;
  final String? title;
  final String? caption;
  final String? category;
  final String fundingMode;
  final String currencyCode;
  final int? targetAmountMinor;
  final int? monthlyGoalMinor;
  final int? campaignDurationDays;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? deadline;
  final DateTime? nextReviewAt;
  final String? beneficiaryType;
  final String? beneficiaryName;
  final int? petId;
  final String? urgency;
  final String? treatmentProvider;
  final int? estimatedExpenseMinor;
  final Map<String, dynamic>? spendingPlan;
  final String? locationText;
  final int? countryId;
  final int? stateId;
  final int? cityId;
  final int? subDistrictId;
  final String? bdAddressMode;
  final int? bdDivisionId;
  final int? bdDistrictId;
  final int? bdCityCorporationId;
  final int? bdZoneId;
  final int? bdWardId;
  final int? bdUpazilaId;
  final int? bdUnionId;
  final int? bdAreaId;
  final DateTime? submittedAt;
  final List<int> mediaIds;
  final List<String> mediaUrls;

  factory FundraisingDraftRecord.fromJson(Map<String, dynamic> json) {
    final post = (json['post'] is Map)
        ? Map<String, dynamic>.from(json['post'] as Map)
        : const <String, dynamic>{};
    final mediaEntries = (post['media'] as List?) ?? const <dynamic>[];
    final mediaIds = <int>[];
    final mediaUrls = <String>[];
    for (final entry in mediaEntries.whereType<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final media = (map['media'] is Map)
          ? Map<String, dynamic>.from(map['media'] as Map)
          : const <String, dynamic>{};
      final id = fundraisingInt(media['id']);
      if (id != null) mediaIds.add(id);
      final url = media['url']?.toString();
      if (url != null && url.trim().isNotEmpty) {
        mediaUrls.add(MediaUrl.normalize(url));
      }
    }
    return FundraisingDraftRecord(
      id: fundraisingInt(json['id']) ?? 0,
      status: (json['status'] ?? 'DRAFT').toString(),
      publicId: json['publicId']?.toString(),
      slug: json['slug']?.toString(),
      title: json['title']?.toString(),
      caption: post['caption']?.toString(),
      category: json['category']?.toString(),
      fundingMode: (json['fundingMode'] ?? 'ONE_TIME').toString(),
      currencyCode: (json['currencyCode'] ?? 'BDT').toString(),
      targetAmountMinor: _parseMoneyMinor(
        json['targetAmountMinor'],
        fallback: json['targetAmount'],
      ),
      monthlyGoalMinor: _parseMoneyMinor(json['monthlyGoalMinor']),
      startsAt: _parseDate(json['startsAt']),
      endsAt: _parseDate(json['endsAt'] ?? json['deadline']),
      deadline: _parseDate(json['deadline'] ?? json['endsAt']),
      nextReviewAt: _parseDate(json['nextReviewAt']),
      beneficiaryType: json['beneficiaryType']?.toString(),
      beneficiaryName: json['beneficiaryName']?.toString(),
      petId: fundraisingInt(json['petId']),
      urgency: json['urgency']?.toString(),
      treatmentProvider: json['treatmentProvider']?.toString(),
      estimatedExpenseMinor: _parseMoneyMinor(
        json['estimatedExpenseMinor'],
        fallback: json['estimatedExpense'],
      ),
      spendingPlan: json['spendingPlan'] is Map
          ? Map<String, dynamic>.from(json['spendingPlan'] as Map)
          : null,
      locationText: json['locationText']?.toString(),
      countryId: fundraisingInt(json['countryId']),
      stateId: fundraisingInt(json['stateId']),
      cityId: fundraisingInt(json['cityId']),
      subDistrictId: fundraisingInt(json['subDistrictId']),
      bdAddressMode: json['bdAddressMode']?.toString(),
      bdDivisionId: fundraisingInt(json['bdDivisionId']),
      bdDistrictId: fundraisingInt(json['bdDistrictId']),
      bdCityCorporationId: fundraisingInt(json['bdCityCorporationId']),
      bdZoneId: fundraisingInt(json['bdZoneId']),
      bdWardId: fundraisingInt(json['bdWardId']),
      bdUpazilaId: fundraisingInt(json['bdUpazilaId']),
      bdUnionId: fundraisingInt(json['bdUnionId']),
      bdAreaId: fundraisingInt(json['bdAreaId']),
      submittedAt: _parseDate(json['submittedAt']),
      mediaIds: mediaIds,
      mediaUrls: mediaUrls,
    );
  }

  static int? _parseMoneyMinor(dynamic raw, {dynamic fallback}) {
    final candidate = raw ?? fallback;
    if (candidate == null) return null;
    if (candidate is int) return candidate;
    if (candidate is num) return candidate.toInt();
    return int.tryParse(candidate.toString());
  }

  static DateTime? _parseDate(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class FundraisingDraftRecovery {
  const FundraisingDraftRecovery({
    this.remoteDraftId,
    this.remoteDraftPublicId,
    this.createIdempotencyKey,
    this.submitIdempotencyKey,
    this.stepIndex = 0,
    this.title = '',
    this.shortDescription = '',
    this.story = '',
    this.whatHappened = '',
    this.whyUrgent = '',
    this.fundUsage = '',
    this.category = '',
    this.fundingMode = 'ONE_TIME',
    this.currencyCode = 'BDT',
    this.targetAmountMinor,
    this.monthlyGoalMinor,
    this.campaignDurationDays,
    this.startsAt,
    this.endsAt,
    this.deadline,
    this.nextReviewAt,
    this.beneficiaryType = 'PET',
    this.beneficiaryName = '',
    this.petId,
    this.urgency,
    this.treatmentProvider = '',
    this.estimatedExpenseMinor,
    this.expenseNotes = '',
    this.locationText = '',
    this.countryId,
    this.stateId,
    this.cityId,
    this.subDistrictId,
    this.bdAddressMode,
    this.bdDivisionId,
    this.bdDistrictId,
    this.bdCityCorporationId,
    this.bdZoneId,
    this.bdWardId,
    this.bdUpazilaId,
    this.bdUnionId,
    this.bdAreaId,
    this.divisionName,
    this.districtName,
    this.cityCorporationName,
    this.zoneName,
    this.wardName,
    this.upazilaName,
    this.unionName,
    this.areaName,
    this.customLocationNote = '',
    this.securityLatitude,
    this.securityLongitude,
    this.securityLocationAccuracy,
    this.securityLocationCapturedAt,
    this.expenses = const <FundraisingExpenseItem>[],
    this.mediaIds = const <int>[],
    this.updatedAt,
  });

  final int? remoteDraftId;
  final String? remoteDraftPublicId;
  final String? createIdempotencyKey;
  final String? submitIdempotencyKey;
  final int stepIndex;
  final String title;
  final String shortDescription;
  final String story;
  final String whatHappened;
  final String whyUrgent;
  final String fundUsage;
  final String category;
  final String fundingMode;
  final String currencyCode;
  final int? targetAmountMinor;
  final int? monthlyGoalMinor;
  final int? campaignDurationDays;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? deadline;
  final DateTime? nextReviewAt;
  final String beneficiaryType;
  final String beneficiaryName;
  final int? petId;
  final String? urgency;
  final String treatmentProvider;
  final int? estimatedExpenseMinor;
  final String expenseNotes;
  final String locationText;
  final int? countryId;
  final int? stateId;
  final int? cityId;
  final int? subDistrictId;
  final String? bdAddressMode;
  final int? bdDivisionId;
  final int? bdDistrictId;
  final int? bdCityCorporationId;
  final int? bdZoneId;
  final int? bdWardId;
  final int? bdUpazilaId;
  final int? bdUnionId;
  final int? bdAreaId;
  final String? cityCorporationName;
  final String? zoneName;
  final String? wardName;
  final String? divisionName;
  final String? districtName;
  final String? upazilaName;
  final String? unionName;
  final String? areaName;
  final String customLocationNote;
  final double? securityLatitude;
  final double? securityLongitude;
  final double? securityLocationAccuracy;
  final DateTime? securityLocationCapturedAt;
  final List<FundraisingExpenseItem> expenses;
  final List<int> mediaIds;
  final DateTime? updatedAt;

  factory FundraisingDraftRecovery.empty() {
    return FundraisingDraftRecovery(
      createIdempotencyKey: _defaultIdempotencyKey('draft'),
      submitIdempotencyKey: _defaultIdempotencyKey('submit'),
      expenses: const <FundraisingExpenseItem>[
        FundraisingExpenseItem(code: 'vet', label: 'Veterinary care'),
        FundraisingExpenseItem(code: 'medicine', label: 'Medicine'),
        FundraisingExpenseItem(code: 'transport', label: 'Transport'),
        FundraisingExpenseItem(code: 'care', label: 'Food and care'),
        FundraisingExpenseItem(code: 'other', label: 'Other'),
      ],
    );
  }

  bool get hasMeaningfulContent {
    return title.trim().isNotEmpty ||
        shortDescription.trim().isNotEmpty ||
        story.trim().isNotEmpty ||
        whatHappened.trim().isNotEmpty ||
        whyUrgent.trim().isNotEmpty ||
        fundUsage.trim().isNotEmpty ||
        category.trim().isNotEmpty ||
        beneficiaryName.trim().isNotEmpty ||
        (targetAmountMinor ?? 0) > 0 ||
        (estimatedExpenseMinor ?? 0) > 0 ||
        mediaIds.isNotEmpty;
  }

  int get suggestedTargetMinor {
    final sum = expenses.fold<int>(
      0,
      (total, item) => total + (item.amountMinor ?? 0),
    );
    if (sum > 0) return sum;
    return estimatedExpenseMinor ?? 0;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'remoteDraftId': remoteDraftId,
      'remoteDraftPublicId': remoteDraftPublicId,
      'createIdempotencyKey': createIdempotencyKey,
      'submitIdempotencyKey': submitIdempotencyKey,
      'stepIndex': stepIndex,
      'title': title,
      'shortDescription': shortDescription,
      'story': story,
      'whatHappened': whatHappened,
      'whyUrgent': whyUrgent,
      'fundUsage': fundUsage,
      'category': category,
      'fundingMode': fundingMode,
      'currencyCode': currencyCode,
      'targetAmountMinor': targetAmountMinor,
      'monthlyGoalMinor': monthlyGoalMinor,
      'campaignDurationDays': campaignDurationDays,
      'startsAt': FundraisingDateSerializer.serializeToUtcIso8601(startsAt),
      'endsAt': FundraisingDateSerializer.serializeToUtcIso8601(endsAt),
      'deadline': FundraisingDateSerializer.serializeToUtcIso8601(deadline),
      'nextReviewAt': FundraisingDateSerializer.serializeToUtcIso8601(
        nextReviewAt,
      ),
      'beneficiaryType': beneficiaryType,
      'beneficiaryName': beneficiaryName,
      'petId': petId,
      'urgency': urgency,
      'treatmentProvider': treatmentProvider,
      'estimatedExpenseMinor': estimatedExpenseMinor,
      'expenseNotes': expenseNotes,
      'locationText': locationText,
      'countryId': countryId,
      'stateId': stateId,
      'cityId': cityId,
      'subDistrictId': subDistrictId,
      'bdAddressMode': bdAddressMode,
      'bdDivisionId': bdDivisionId,
      'bdDistrictId': bdDistrictId,
      'bdCityCorporationId': bdCityCorporationId,
      'bdZoneId': bdZoneId,
      'bdWardId': bdWardId,
      'bdUpazilaId': bdUpazilaId,
      'bdUnionId': bdUnionId,
      'cityCorporationName': cityCorporationName,
      'zoneName': zoneName,
      'wardName': wardName,
      'divisionName': divisionName,
      'districtName': districtName,
      'upazilaName': upazilaName,
      'unionName': unionName,
      'areaName': areaName,
      'customLocationNote': customLocationNote,
      'securityLatitude': securityLatitude,
      'securityLongitude': securityLongitude,
      'securityLocationAccuracy': securityLocationAccuracy,
      'securityLocationCapturedAt':
          FundraisingDateSerializer.serializeToUtcIso8601(
            securityLocationCapturedAt,
          ),
      'expenses': expenses.map((item) => item.toJson()).toList(),
      'mediaIds': mediaIds,
      'updatedAt': FundraisingDateSerializer.serializeToUtcIso8601(
        updatedAt ?? DateTime.now(),
      ),
    };
  }

  String encode() => jsonEncode(toJson());

  factory FundraisingDraftRecovery.fromEncoded(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return FundraisingDraftRecovery.empty();
    }
    return FundraisingDraftRecovery.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  factory FundraisingDraftRecovery.fromJson(Map<String, dynamic> json) {
    final empty = FundraisingDraftRecovery.empty();
    final expensesRaw = (json['expenses'] as List?) ?? const <dynamic>[];
    final expenses = expensesRaw
        .whereType<Map>()
        .map(
          (entry) =>
              FundraisingExpenseItem.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();
    final rawStepIndex = fundraisingInt(json['stepIndex']) ?? 0;
    final stepIndex = rawStepIndex
        .clamp(0, kFundraisingWizardStepCount - 1)
        .toInt();
    return FundraisingDraftRecovery(
      remoteDraftId: fundraisingInt(json['remoteDraftId']),
      remoteDraftPublicId: json['remoteDraftPublicId']?.toString(),
      createIdempotencyKey:
          json['createIdempotencyKey']?.toString() ??
          empty.createIdempotencyKey,
      submitIdempotencyKey:
          json['submitIdempotencyKey']?.toString() ??
          empty.submitIdempotencyKey,
      stepIndex: stepIndex,
      title: json['title']?.toString() ?? '',
      shortDescription: json['shortDescription']?.toString() ?? '',
      story: json['story']?.toString() ?? '',
      whatHappened: json['whatHappened']?.toString() ?? '',
      whyUrgent: json['whyUrgent']?.toString() ?? '',
      fundUsage: json['fundUsage']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      fundingMode: json['fundingMode']?.toString() ?? 'ONE_TIME',
      currencyCode: json['currencyCode']?.toString() ?? 'BDT',
      targetAmountMinor: fundraisingInt(json['targetAmountMinor']),
      monthlyGoalMinor: fundraisingInt(json['monthlyGoalMinor']),
      campaignDurationDays: fundraisingInt(json['campaignDurationDays']),
      startsAt: FundraisingDateSerializer.parseLegacyDateField(
        json['startsAt'],
      ),
      endsAt: FundraisingDateSerializer.parseLegacyDateField(
        json['endsAt'] ?? json['deadline'],
      ),
      deadline: FundraisingDateSerializer.parseLegacyDateField(
        json['deadline'] ?? json['endsAt'],
      ),
      nextReviewAt: FundraisingDateSerializer.parseLegacyDateField(
        json['nextReviewAt'],
      ),
      beneficiaryType: json['beneficiaryType']?.toString() ?? 'PET',
      beneficiaryName: json['beneficiaryName']?.toString() ?? '',
      petId: fundraisingInt(json['petId']),
      urgency: json['urgency']?.toString(),
      treatmentProvider: json['treatmentProvider']?.toString() ?? '',
      estimatedExpenseMinor: fundraisingInt(json['estimatedExpenseMinor']),
      expenseNotes: json['expenseNotes']?.toString() ?? '',
      locationText: json['locationText']?.toString() ?? '',
      countryId: fundraisingInt(json['countryId']),
      stateId: fundraisingInt(json['stateId']),
      cityId: fundraisingInt(json['cityId']),
      subDistrictId: fundraisingInt(json['subDistrictId']),
      bdAddressMode: json['bdAddressMode']?.toString(),
      bdDivisionId: fundraisingInt(json['bdDivisionId']),
      bdDistrictId: fundraisingInt(json['bdDistrictId']),
      bdCityCorporationId: fundraisingInt(json['bdCityCorporationId']),
      bdZoneId: fundraisingInt(json['bdZoneId']),
      bdWardId: fundraisingInt(json['bdWardId']),
      bdUpazilaId: fundraisingInt(json['bdUpazilaId']),
      bdUnionId: fundraisingInt(json['bdUnionId']),
      bdAreaId: fundraisingInt(json['bdAreaId']),
      cityCorporationName: json['cityCorporationName']?.toString(),
      zoneName: json['zoneName']?.toString(),
      wardName: json['wardName']?.toString(),
      divisionName: json['divisionName']?.toString(),
      districtName: json['districtName']?.toString(),
      upazilaName: json['upazilaName']?.toString(),
      unionName: json['unionName']?.toString(),
      areaName: json['areaName']?.toString(),
      customLocationNote: json['customLocationNote']?.toString() ?? '',
      securityLatitude: fundraisingDouble(json['securityLatitude']),
      securityLongitude: fundraisingDouble(json['securityLongitude']),
      securityLocationAccuracy: fundraisingDouble(
        json['securityLocationAccuracy'],
      ),
      securityLocationCapturedAt:
          FundraisingDateSerializer.parseLegacyDateField(
            json['securityLocationCapturedAt'],
          ),
      expenses: expenses.isEmpty ? empty.expenses : expenses,
      mediaIds: ((json['mediaIds'] as List?) ?? const <dynamic>[])
          .map(fundraisingInt)
          .whereType<int>()
          .toList(growable: false),
      updatedAt: FundraisingDateSerializer.parseLegacyDateField(
        json['updatedAt'],
      ),
    );
  }

  factory FundraisingDraftRecovery.fromServerDraft(
    FundraisingDraftRecord draft, {
    FundraisingDraftRecovery? base,
  }) {
    final current = base ?? FundraisingDraftRecovery.empty();
    final serverExpenses = _expensesFromSpendingPlan(draft.spendingPlan);
    return current.copyWith(
      remoteDraftId: draft.id,
      remoteDraftPublicId: draft.publicId,
      title: draft.title ?? current.title,
      shortDescription: current.shortDescription,
      story: current.story.trim().isNotEmpty
          ? current.story
          : (draft.caption ?? current.story),
      whatHappened: current.whatHappened,
      whyUrgent: current.whyUrgent,
      fundUsage: current.fundUsage,
      category: draft.category ?? current.category,
      fundingMode: draft.fundingMode,
      currencyCode: draft.currencyCode,
      targetAmountMinor: draft.targetAmountMinor ?? current.targetAmountMinor,
      monthlyGoalMinor: draft.monthlyGoalMinor ?? current.monthlyGoalMinor,
      campaignDurationDays: current.campaignDurationDays,
      startsAt: draft.startsAt ?? current.startsAt,
      endsAt: draft.endsAt ?? current.endsAt,
      deadline: draft.deadline ?? current.deadline,
      nextReviewAt: draft.nextReviewAt ?? current.nextReviewAt,
      beneficiaryType: draft.beneficiaryType ?? current.beneficiaryType,
      beneficiaryName: draft.beneficiaryName ?? current.beneficiaryName,
      petId: draft.petId ?? current.petId,
      urgency: draft.urgency ?? current.urgency,
      treatmentProvider: draft.treatmentProvider ?? current.treatmentProvider,
      estimatedExpenseMinor:
          draft.estimatedExpenseMinor ?? current.estimatedExpenseMinor,
      expenseNotes: current.expenseNotes,
      locationText: draft.locationText ?? current.locationText,
      countryId: draft.countryId ?? current.countryId,
      stateId: draft.stateId ?? current.stateId,
      cityId: draft.cityId ?? current.cityId,
      subDistrictId: draft.subDistrictId ?? current.subDistrictId,
      bdAddressMode: draft.bdAddressMode ?? current.bdAddressMode,
      bdDivisionId: draft.bdDivisionId ?? current.bdDivisionId,
      bdDistrictId: draft.bdDistrictId ?? current.bdDistrictId,
      bdCityCorporationId:
          draft.bdCityCorporationId ?? current.bdCityCorporationId,
      bdZoneId: draft.bdZoneId ?? current.bdZoneId,
      bdWardId: draft.bdWardId ?? current.bdWardId,
      bdUpazilaId: draft.bdUpazilaId ?? current.bdUpazilaId,
      bdUnionId: draft.bdUnionId ?? current.bdUnionId,
      bdAreaId: draft.bdAreaId ?? current.bdAreaId,
      cityCorporationName: current.cityCorporationName,
      zoneName: current.zoneName,
      wardName: current.wardName,
      unionName: current.unionName,
      mediaIds: draft.mediaIds.isNotEmpty ? draft.mediaIds : current.mediaIds,
      expenses: serverExpenses.isNotEmpty ? serverExpenses : current.expenses,
      updatedAt: DateTime.now(),
    );
  }

  FundraisingDraftRecovery copyWith({
    int? remoteDraftId,
    bool clearRemoteDraftId = false,
    String? remoteDraftPublicId,
    String? createIdempotencyKey,
    String? submitIdempotencyKey,
    int? stepIndex,
    String? title,
    String? shortDescription,
    String? story,
    String? whatHappened,
    String? whyUrgent,
    String? fundUsage,
    String? category,
    String? fundingMode,
    String? currencyCode,
    int? targetAmountMinor,
    bool clearTargetAmountMinor = false,
    int? monthlyGoalMinor,
    bool clearMonthlyGoalMinor = false,
    int? campaignDurationDays,
    bool clearCampaignDurationDays = false,
    DateTime? startsAt,
    bool clearStartsAt = false,
    DateTime? endsAt,
    bool clearEndsAt = false,
    DateTime? deadline,
    bool clearDeadline = false,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
    String? beneficiaryType,
    String? beneficiaryName,
    int? petId,
    bool clearPetId = false,
    String? urgency,
    bool clearUrgency = false,
    String? treatmentProvider,
    int? estimatedExpenseMinor,
    bool clearEstimatedExpenseMinor = false,
    String? expenseNotes,
    String? locationText,
    int? countryId,
    bool clearCountryId = false,
    int? stateId,
    bool clearStateId = false,
    int? cityId,
    bool clearCityId = false,
    int? subDistrictId,
    bool clearSubDistrictId = false,
    String? bdAddressMode,
    bool clearBdAddressMode = false,
    int? bdDivisionId,
    bool clearBdDivisionId = false,
    int? bdDistrictId,
    bool clearBdDistrictId = false,
    int? bdCityCorporationId,
    bool clearBdCityCorporationId = false,
    int? bdZoneId,
    bool clearBdZoneId = false,
    int? bdWardId,
    bool clearBdWardId = false,
    int? bdUpazilaId,
    bool clearBdUpazilaId = false,
    int? bdUnionId,
    bool clearBdUnionId = false,
    int? bdAreaId,
    bool clearBdAreaId = false,
    String? cityCorporationName,
    bool clearCityCorporationName = false,
    String? zoneName,
    bool clearZoneName = false,
    String? wardName,
    bool clearWardName = false,
    String? divisionName,
    bool clearDivisionName = false,
    String? districtName,
    bool clearDistrictName = false,
    String? upazilaName,
    bool clearUpazilaName = false,
    String? unionName,
    bool clearUnionName = false,
    String? areaName,
    bool clearAreaName = false,
    String? customLocationNote,
    double? securityLatitude,
    bool clearSecurityLatitude = false,
    double? securityLongitude,
    bool clearSecurityLongitude = false,
    double? securityLocationAccuracy,
    bool clearSecurityLocationAccuracy = false,
    DateTime? securityLocationCapturedAt,
    bool clearSecurityLocationCapturedAt = false,
    List<FundraisingExpenseItem>? expenses,
    List<int>? mediaIds,
    DateTime? updatedAt,
  }) {
    return FundraisingDraftRecovery(
      remoteDraftId: clearRemoteDraftId
          ? null
          : (remoteDraftId ?? this.remoteDraftId),
      remoteDraftPublicId: remoteDraftPublicId ?? this.remoteDraftPublicId,
      createIdempotencyKey: createIdempotencyKey ?? this.createIdempotencyKey,
      submitIdempotencyKey: submitIdempotencyKey ?? this.submitIdempotencyKey,
      stepIndex: stepIndex ?? this.stepIndex,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      story: story ?? this.story,
      whatHappened: whatHappened ?? this.whatHappened,
      whyUrgent: whyUrgent ?? this.whyUrgent,
      fundUsage: fundUsage ?? this.fundUsage,
      category: category ?? this.category,
      fundingMode: fundingMode ?? this.fundingMode,
      currencyCode: currencyCode ?? this.currencyCode,
      targetAmountMinor: clearTargetAmountMinor
          ? null
          : (targetAmountMinor ?? this.targetAmountMinor),
      monthlyGoalMinor: clearMonthlyGoalMinor
          ? null
          : (monthlyGoalMinor ?? this.monthlyGoalMinor),
      campaignDurationDays: clearCampaignDurationDays
          ? null
          : (campaignDurationDays ?? this.campaignDurationDays),
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      nextReviewAt: clearNextReviewAt
          ? null
          : (nextReviewAt ?? this.nextReviewAt),
      beneficiaryType: beneficiaryType ?? this.beneficiaryType,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      petId: clearPetId ? null : (petId ?? this.petId),
      urgency: clearUrgency ? null : (urgency ?? this.urgency),
      treatmentProvider: treatmentProvider ?? this.treatmentProvider,
      estimatedExpenseMinor: clearEstimatedExpenseMinor
          ? null
          : (estimatedExpenseMinor ?? this.estimatedExpenseMinor),
      expenseNotes: expenseNotes ?? this.expenseNotes,
      locationText: locationText ?? this.locationText,
      countryId: clearCountryId ? null : (countryId ?? this.countryId),
      stateId: clearStateId ? null : (stateId ?? this.stateId),
      cityId: clearCityId ? null : (cityId ?? this.cityId),
      subDistrictId: clearSubDistrictId
          ? null
          : (subDistrictId ?? this.subDistrictId),
      bdAddressMode: clearBdAddressMode
          ? null
          : (bdAddressMode ?? this.bdAddressMode),
      bdDivisionId: clearBdDivisionId
          ? null
          : (bdDivisionId ?? this.bdDivisionId),
      bdDistrictId: clearBdDistrictId
          ? null
          : (bdDistrictId ?? this.bdDistrictId),
      bdCityCorporationId: clearBdCityCorporationId
          ? null
          : (bdCityCorporationId ?? this.bdCityCorporationId),
      bdZoneId: clearBdZoneId ? null : (bdZoneId ?? this.bdZoneId),
      bdWardId: clearBdWardId ? null : (bdWardId ?? this.bdWardId),
      bdUpazilaId: clearBdUpazilaId ? null : (bdUpazilaId ?? this.bdUpazilaId),
      bdUnionId: clearBdUnionId ? null : (bdUnionId ?? this.bdUnionId),
      bdAreaId: clearBdAreaId ? null : (bdAreaId ?? this.bdAreaId),
      cityCorporationName: clearCityCorporationName
          ? null
          : (cityCorporationName ?? this.cityCorporationName),
      zoneName: clearZoneName ? null : (zoneName ?? this.zoneName),
      wardName: clearWardName ? null : (wardName ?? this.wardName),
      divisionName: clearDivisionName
          ? null
          : (divisionName ?? this.divisionName),
      districtName: clearDistrictName
          ? null
          : (districtName ?? this.districtName),
      upazilaName: clearUpazilaName ? null : (upazilaName ?? this.upazilaName),
      unionName: clearUnionName ? null : (unionName ?? this.unionName),
      areaName: clearAreaName ? null : (areaName ?? this.areaName),
      customLocationNote: customLocationNote ?? this.customLocationNote,
      securityLatitude: clearSecurityLatitude
          ? null
          : (securityLatitude ?? this.securityLatitude),
      securityLongitude: clearSecurityLongitude
          ? null
          : (securityLongitude ?? this.securityLongitude),
      securityLocationAccuracy: clearSecurityLocationAccuracy
          ? null
          : (securityLocationAccuracy ?? this.securityLocationAccuracy),
      securityLocationCapturedAt: clearSecurityLocationCapturedAt
          ? null
          : (securityLocationCapturedAt ?? this.securityLocationCapturedAt),
      expenses: expenses ?? this.expenses,
      mediaIds: mediaIds ?? this.mediaIds,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static List<FundraisingExpenseItem> _expensesFromSpendingPlan(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return const <FundraisingExpenseItem>[];
    final entries = <FundraisingExpenseItem>[];
    final lines = raw['lines'];
    if (lines is List) {
      for (final entry in lines.whereType<Map>()) {
        final map = Map<String, dynamic>.from(entry);
        entries.add(
          FundraisingExpenseItem(
            code: map['code']?.toString() ?? '',
            label: map['label']?.toString() ?? '',
            amountMinor: fundraisingInt(map['amountMinor']),
          ),
        );
      }
    }
    return entries;
  }

  static String _defaultIdempotencyKey(String prefix) {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$micros';
  }
}

/// Mirrors the API's `validateSelection` branch rule (see
/// `location-store.ts`): a Bangladesh location is canonically complete only
/// when its full branch of IDs is present — rural needs division, district,
/// upazila, AND union; urban needs division, district, city corporation,
/// zone, AND ward. Display labels (e.g. a restored `locationText`) are not
/// sufficient on their own — a stale/partial saved draft can have labels
/// without the IDs the API actually validates, and must not be treated as
/// complete.
bool isLocationCanonicallyComplete(FundraisingDraftRecovery draft) {
  final hasRural = draft.bdUpazilaId != null || draft.bdUnionId != null;
  final hasUrban =
      draft.bdCityCorporationId != null ||
      draft.bdZoneId != null ||
      draft.bdWardId != null;
  if (hasRural && hasUrban) return false;
  if (hasRural) {
    return draft.bdDivisionId != null &&
        draft.bdDistrictId != null &&
        draft.bdUpazilaId != null &&
        draft.bdUnionId != null;
  }
  if (hasUrban) {
    return draft.bdDivisionId != null &&
        draft.bdDistrictId != null &&
        draft.bdCityCorporationId != null &&
        draft.bdZoneId != null &&
        draft.bdWardId != null;
  }
  return false;
}
