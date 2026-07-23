import 'dart:convert';

import 'package:furtail_app/core/media/media_url.dart';

enum FundraisingWizardStep {
  eligibility,
  fundraiserType,
  storyAndGoal,
  caseDetails,
  location,
  evidence,
  payoutReadiness,
  preview,
}

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
      amountMinor: (json['amountMinor'] as num?)?.toInt(),
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
    this.currencyCode = 'BDT',
    this.targetAmountMinor,
    this.deadline,
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
    this.bdDivisionId,
    this.bdDistrictId,
    this.bdUpazilaId,
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
  final String currencyCode;
  final int? targetAmountMinor;
  final DateTime? deadline;
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
  final int? bdDivisionId;
  final int? bdDistrictId;
  final int? bdUpazilaId;
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
      final id = (media['id'] as num?)?.toInt();
      if (id != null) mediaIds.add(id);
      final url = media['url']?.toString();
      if (url != null && url.trim().isNotEmpty) {
        mediaUrls.add(MediaUrl.normalize(url));
      }
    }
    return FundraisingDraftRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'DRAFT').toString(),
      publicId: json['publicId']?.toString(),
      slug: json['slug']?.toString(),
      title: json['title']?.toString(),
      caption: post['caption']?.toString(),
      category: json['category']?.toString(),
      currencyCode: (json['currencyCode'] ?? 'BDT').toString(),
      targetAmountMinor: _parseMoneyMinor(
        json['targetAmountMinor'],
        fallback: json['targetAmount'],
      ),
      deadline: _parseDate(json['deadline']),
      beneficiaryType: json['beneficiaryType']?.toString(),
      beneficiaryName: json['beneficiaryName']?.toString(),
      petId: (json['petId'] as num?)?.toInt(),
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
      countryId: (json['countryId'] as num?)?.toInt(),
      stateId: (json['stateId'] as num?)?.toInt(),
      cityId: (json['cityId'] as num?)?.toInt(),
      subDistrictId: (json['subDistrictId'] as num?)?.toInt(),
      bdDivisionId: (json['bdDivisionId'] as num?)?.toInt(),
      bdDistrictId: (json['bdDistrictId'] as num?)?.toInt(),
      bdUpazilaId: (json['bdUpazilaId'] as num?)?.toInt(),
      bdAreaId: (json['bdAreaId'] as num?)?.toInt(),
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
    this.story = '',
    this.category = '',
    this.currencyCode = 'BDT',
    this.targetAmountMinor,
    this.deadline,
    this.beneficiaryType = 'PET',
    this.beneficiaryName = '',
    this.petId,
    this.urgency,
    this.treatmentProvider = '',
    this.estimatedExpenseMinor,
    this.locationText = '',
    this.countryId,
    this.stateId,
    this.cityId,
    this.subDistrictId,
    this.bdDivisionId,
    this.bdDistrictId,
    this.bdUpazilaId,
    this.bdAreaId,
    this.divisionName,
    this.districtName,
    this.upazilaName,
    this.areaName,
    this.customLocationNote = '',
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
  final String story;
  final String category;
  final String currencyCode;
  final int? targetAmountMinor;
  final DateTime? deadline;
  final String beneficiaryType;
  final String beneficiaryName;
  final int? petId;
  final String? urgency;
  final String treatmentProvider;
  final int? estimatedExpenseMinor;
  final String locationText;
  final int? countryId;
  final int? stateId;
  final int? cityId;
  final int? subDistrictId;
  final int? bdDivisionId;
  final int? bdDistrictId;
  final int? bdUpazilaId;
  final int? bdAreaId;
  final String? divisionName;
  final String? districtName;
  final String? upazilaName;
  final String? areaName;
  final String customLocationNote;
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
        story.trim().isNotEmpty ||
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
      'story': story,
      'category': category,
      'currencyCode': currencyCode,
      'targetAmountMinor': targetAmountMinor,
      'deadline': deadline?.toIso8601String(),
      'beneficiaryType': beneficiaryType,
      'beneficiaryName': beneficiaryName,
      'petId': petId,
      'urgency': urgency,
      'treatmentProvider': treatmentProvider,
      'estimatedExpenseMinor': estimatedExpenseMinor,
      'locationText': locationText,
      'countryId': countryId,
      'stateId': stateId,
      'cityId': cityId,
      'subDistrictId': subDistrictId,
      'bdDivisionId': bdDivisionId,
      'bdDistrictId': bdDistrictId,
      'bdUpazilaId': bdUpazilaId,
      'bdAreaId': bdAreaId,
      'divisionName': divisionName,
      'districtName': districtName,
      'upazilaName': upazilaName,
      'areaName': areaName,
      'customLocationNote': customLocationNote,
      'expenses': expenses.map((item) => item.toJson()).toList(),
      'mediaIds': mediaIds,
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
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
    return FundraisingDraftRecovery(
      remoteDraftId: (json['remoteDraftId'] as num?)?.toInt(),
      remoteDraftPublicId: json['remoteDraftPublicId']?.toString(),
      createIdempotencyKey:
          json['createIdempotencyKey']?.toString() ??
          empty.createIdempotencyKey,
      submitIdempotencyKey:
          json['submitIdempotencyKey']?.toString() ??
          empty.submitIdempotencyKey,
      stepIndex: (json['stepIndex'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      story: json['story']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      currencyCode: json['currencyCode']?.toString() ?? 'BDT',
      targetAmountMinor: (json['targetAmountMinor'] as num?)?.toInt(),
      deadline: FundraisingDraftRecord._parseDate(json['deadline']),
      beneficiaryType: json['beneficiaryType']?.toString() ?? 'PET',
      beneficiaryName: json['beneficiaryName']?.toString() ?? '',
      petId: (json['petId'] as num?)?.toInt(),
      urgency: json['urgency']?.toString(),
      treatmentProvider: json['treatmentProvider']?.toString() ?? '',
      estimatedExpenseMinor: (json['estimatedExpenseMinor'] as num?)?.toInt(),
      locationText: json['locationText']?.toString() ?? '',
      countryId: (json['countryId'] as num?)?.toInt(),
      stateId: (json['stateId'] as num?)?.toInt(),
      cityId: (json['cityId'] as num?)?.toInt(),
      subDistrictId: (json['subDistrictId'] as num?)?.toInt(),
      bdDivisionId: (json['bdDivisionId'] as num?)?.toInt(),
      bdDistrictId: (json['bdDistrictId'] as num?)?.toInt(),
      bdUpazilaId: (json['bdUpazilaId'] as num?)?.toInt(),
      bdAreaId: (json['bdAreaId'] as num?)?.toInt(),
      divisionName: json['divisionName']?.toString(),
      districtName: json['districtName']?.toString(),
      upazilaName: json['upazilaName']?.toString(),
      areaName: json['areaName']?.toString(),
      customLocationNote: json['customLocationNote']?.toString() ?? '',
      expenses: expenses.isEmpty ? empty.expenses : expenses,
      mediaIds: ((json['mediaIds'] as List?) ?? const <dynamic>[])
          .map((entry) => (entry as num).toInt())
          .toList(),
      updatedAt: FundraisingDraftRecord._parseDate(json['updatedAt']),
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
      story: draft.caption ?? current.story,
      category: draft.category ?? current.category,
      currencyCode: draft.currencyCode,
      targetAmountMinor: draft.targetAmountMinor ?? current.targetAmountMinor,
      deadline: draft.deadline ?? current.deadline,
      beneficiaryType: draft.beneficiaryType ?? current.beneficiaryType,
      beneficiaryName: draft.beneficiaryName ?? current.beneficiaryName,
      petId: draft.petId ?? current.petId,
      urgency: draft.urgency ?? current.urgency,
      treatmentProvider: draft.treatmentProvider ?? current.treatmentProvider,
      estimatedExpenseMinor:
          draft.estimatedExpenseMinor ?? current.estimatedExpenseMinor,
      locationText: draft.locationText ?? current.locationText,
      countryId: draft.countryId ?? current.countryId,
      stateId: draft.stateId ?? current.stateId,
      cityId: draft.cityId ?? current.cityId,
      subDistrictId: draft.subDistrictId ?? current.subDistrictId,
      bdDivisionId: draft.bdDivisionId ?? current.bdDivisionId,
      bdDistrictId: draft.bdDistrictId ?? current.bdDistrictId,
      bdUpazilaId: draft.bdUpazilaId ?? current.bdUpazilaId,
      bdAreaId: draft.bdAreaId ?? current.bdAreaId,
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
    String? story,
    String? category,
    String? currencyCode,
    int? targetAmountMinor,
    bool clearTargetAmountMinor = false,
    DateTime? deadline,
    bool clearDeadline = false,
    String? beneficiaryType,
    String? beneficiaryName,
    int? petId,
    bool clearPetId = false,
    String? urgency,
    bool clearUrgency = false,
    String? treatmentProvider,
    int? estimatedExpenseMinor,
    bool clearEstimatedExpenseMinor = false,
    String? locationText,
    int? countryId,
    bool clearCountryId = false,
    int? stateId,
    bool clearStateId = false,
    int? cityId,
    bool clearCityId = false,
    int? subDistrictId,
    bool clearSubDistrictId = false,
    int? bdDivisionId,
    bool clearBdDivisionId = false,
    int? bdDistrictId,
    bool clearBdDistrictId = false,
    int? bdUpazilaId,
    bool clearBdUpazilaId = false,
    int? bdAreaId,
    bool clearBdAreaId = false,
    String? divisionName,
    bool clearDivisionName = false,
    String? districtName,
    bool clearDistrictName = false,
    String? upazilaName,
    bool clearUpazilaName = false,
    String? areaName,
    bool clearAreaName = false,
    String? customLocationNote,
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
      story: story ?? this.story,
      category: category ?? this.category,
      currencyCode: currencyCode ?? this.currencyCode,
      targetAmountMinor: clearTargetAmountMinor
          ? null
          : (targetAmountMinor ?? this.targetAmountMinor),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      beneficiaryType: beneficiaryType ?? this.beneficiaryType,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      petId: clearPetId ? null : (petId ?? this.petId),
      urgency: clearUrgency ? null : (urgency ?? this.urgency),
      treatmentProvider: treatmentProvider ?? this.treatmentProvider,
      estimatedExpenseMinor: clearEstimatedExpenseMinor
          ? null
          : (estimatedExpenseMinor ?? this.estimatedExpenseMinor),
      locationText: locationText ?? this.locationText,
      countryId: clearCountryId ? null : (countryId ?? this.countryId),
      stateId: clearStateId ? null : (stateId ?? this.stateId),
      cityId: clearCityId ? null : (cityId ?? this.cityId),
      subDistrictId: clearSubDistrictId
          ? null
          : (subDistrictId ?? this.subDistrictId),
      bdDivisionId: clearBdDivisionId
          ? null
          : (bdDivisionId ?? this.bdDivisionId),
      bdDistrictId: clearBdDistrictId
          ? null
          : (bdDistrictId ?? this.bdDistrictId),
      bdUpazilaId: clearBdUpazilaId ? null : (bdUpazilaId ?? this.bdUpazilaId),
      bdAreaId: clearBdAreaId ? null : (bdAreaId ?? this.bdAreaId),
      divisionName: clearDivisionName
          ? null
          : (divisionName ?? this.divisionName),
      districtName: clearDistrictName
          ? null
          : (districtName ?? this.districtName),
      upazilaName: clearUpazilaName ? null : (upazilaName ?? this.upazilaName),
      areaName: clearAreaName ? null : (areaName ?? this.areaName),
      customLocationNote: customLocationNote ?? this.customLocationNote,
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
            amountMinor: (map['amountMinor'] as num?)?.toInt(),
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
