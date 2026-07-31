import 'dart:convert';

import '../services/fundraising_json.dart';

enum FundraisingDonationCheckoutStatus {
  created,
  paymentPending,
  processing,
  succeeded,
  failed,
  cancelled,
  expired,
  onHoldReview,
}

enum FundraisingDonationErrorType {
  validation,
  offline,
  timeout,
  sessionExpired,
  cancelled,
  paymentFailed,
  unknown,
}

class FundraisingDonationFailure {
  const FundraisingDonationFailure({
    required this.type,
    this.code,
    this.message,
  });

  final FundraisingDonationErrorType type;
  final String? code;
  final String? message;
}

class FundraisingDonationDraft {
  const FundraisingDonationDraft({
    required this.amountMinor,
    required this.isAnonymous,
    required this.supportMessage,
    required this.consentAccepted,
    required this.paymentMethodLabel,
  });

  final int amountMinor;
  final bool isAnonymous;
  final String supportMessage;
  final bool consentAccepted;
  final String paymentMethodLabel;
}

class FundraisingDonationIntentSnapshot {
  const FundraisingDonationIntentSnapshot({
    required this.id,
    required this.publicId,
    required this.referenceId,
    required this.status,
    required this.amountMinor,
    required this.currencyCode,
    required this.expiresAt,
    this.finalizedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String publicId;
  final String referenceId;
  final String status;
  final int amountMinor;
  final String currencyCode;
  final DateTime expiresAt;
  final DateTime? finalizedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FundraisingDonationIntentSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return FundraisingDonationIntentSnapshot(
      id: fundraisingInt(json['id']) ?? 0,
      publicId: json['publicId']?.toString() ?? '',
      referenceId: json['referenceId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      amountMinor: _parseInt(json['amountMinor']),
      currencyCode: json['currencyCode']?.toString() ?? 'BDT',
      expiresAt:
          _parseDate(json['expiresAt']) ??
          DateTime.now().add(const Duration(minutes: 30)),
      finalizedAt: _parseDate(json['finalizedAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class FundraisingDonationPaymentSnapshot {
  const FundraisingDonationPaymentSnapshot({
    required this.provider,
    this.redirectUrl,
    this.providerPaymentId,
    this.logId,
    this.paymentAttemptId,
  });

  final String provider;
  final String? redirectUrl;
  final String? providerPaymentId;
  final String? logId;
  final int? paymentAttemptId;

  factory FundraisingDonationPaymentSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return FundraisingDonationPaymentSnapshot(
      provider: json['provider']?.toString() ?? 'wpa',
      redirectUrl: _firstNonEmptyString(<Object?>[
        json['redirectUrl'],
        json['providerRedirectUrl'],
        json['paymentUrl'],
        json['checkoutUrl'],
        json['url'],
      ]),
      providerPaymentId: json['providerPaymentId']?.toString(),
      logId: json['logId']?.toString(),
      paymentAttemptId: fundraisingInt(json['paymentAttemptId']),
    );
  }
}

class FundraisingDonationCheckoutResponse {
  const FundraisingDonationCheckoutResponse({
    required this.donationIntent,
    required this.reused,
    this.payment,
  });

  final FundraisingDonationIntentSnapshot donationIntent;
  final FundraisingDonationPaymentSnapshot? payment;
  final bool reused;

  factory FundraisingDonationCheckoutResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawPayment = json['payment'];
    final topLevelRedirectUrl = _firstNonEmptyString(<Object?>[
      json['redirectUrl'],
      json['providerRedirectUrl'],
      json['paymentUrl'],
      json['checkoutUrl'],
    ]);
    FundraisingDonationPaymentSnapshot? payment;
    if (rawPayment is Map) {
      final nested = FundraisingDonationPaymentSnapshot.fromJson(
        Map<String, dynamic>.from(rawPayment),
      );
      payment = FundraisingDonationPaymentSnapshot(
        provider: nested.provider,
        redirectUrl: nested.redirectUrl ?? topLevelRedirectUrl,
        providerPaymentId: nested.providerPaymentId,
        logId: nested.logId,
        paymentAttemptId: nested.paymentAttemptId,
      );
    } else if (topLevelRedirectUrl != null) {
      payment = FundraisingDonationPaymentSnapshot(
        provider: json['provider']?.toString() ?? 'wpa',
        redirectUrl: topLevelRedirectUrl,
      );
    }

    return FundraisingDonationCheckoutResponse(
      donationIntent: FundraisingDonationIntentSnapshot.fromJson(
        Map<String, dynamic>.from(
          (json['donationIntent'] as Map?) ?? const <String, dynamic>{},
        ),
      ),
      payment: payment,
      reused: json['reused'] == true,
    );
  }
}

class FundraisingDonationCheckoutRecord {
  const FundraisingDonationCheckoutRecord({
    required this.attemptId,
    required this.campaignId,
    required this.campaignTitle,
    required this.amountMinor,
    required this.currencyCode,
    required this.isAnonymous,
    required this.supportMessage,
    required this.paymentMethodLabel,
    required this.status,
    required this.consentAccepted,
    required this.createdAt,
    required this.updatedAt,
    this.intentId,
    this.intentPublicId,
    this.referenceId,
    this.provider,
    this.redirectUrl,
    this.expiresAt,
    this.confirmedAt,
    this.failure,
  });

  final String attemptId;
  final int campaignId;
  final String campaignTitle;
  final int amountMinor;
  final String currencyCode;
  final bool isAnonymous;
  final String supportMessage;
  final String paymentMethodLabel;
  final FundraisingDonationCheckoutStatus status;
  final bool consentAccepted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? intentId;
  final String? intentPublicId;
  final String? referenceId;
  final String? provider;
  final String? redirectUrl;
  final DateTime? expiresAt;
  final DateTime? confirmedAt;
  final FundraisingDonationFailure? failure;

  bool get isTerminal =>
      status == FundraisingDonationCheckoutStatus.succeeded ||
      status == FundraisingDonationCheckoutStatus.failed ||
      status == FundraisingDonationCheckoutStatus.cancelled ||
      status == FundraisingDonationCheckoutStatus.expired ||
      status == FundraisingDonationCheckoutStatus.onHoldReview;

  FundraisingDonationCheckoutRecord copyWith({
    String? attemptId,
    int? campaignId,
    String? campaignTitle,
    int? amountMinor,
    String? currencyCode,
    bool? isAnonymous,
    String? supportMessage,
    String? paymentMethodLabel,
    FundraisingDonationCheckoutStatus? status,
    bool? consentAccepted,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? intentId,
    bool clearIntentId = false,
    String? intentPublicId,
    bool clearIntentPublicId = false,
    String? referenceId,
    bool clearReferenceId = false,
    String? provider,
    bool clearProvider = false,
    String? redirectUrl,
    bool clearRedirectUrl = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    DateTime? confirmedAt,
    bool clearConfirmedAt = false,
    FundraisingDonationFailure? failure,
    bool clearFailure = false,
  }) {
    return FundraisingDonationCheckoutRecord(
      attemptId: attemptId ?? this.attemptId,
      campaignId: campaignId ?? this.campaignId,
      campaignTitle: campaignTitle ?? this.campaignTitle,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      supportMessage: supportMessage ?? this.supportMessage,
      paymentMethodLabel: paymentMethodLabel ?? this.paymentMethodLabel,
      status: status ?? this.status,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      intentId: clearIntentId ? null : (intentId ?? this.intentId),
      intentPublicId: clearIntentPublicId
          ? null
          : (intentPublicId ?? this.intentPublicId),
      referenceId: clearReferenceId ? null : (referenceId ?? this.referenceId),
      provider: clearProvider ? null : (provider ?? this.provider),
      redirectUrl: clearRedirectUrl ? null : (redirectUrl ?? this.redirectUrl),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      confirmedAt: clearConfirmedAt ? null : (confirmedAt ?? this.confirmedAt),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attemptId': attemptId,
      'campaignId': campaignId,
      'campaignTitle': campaignTitle,
      'amountMinor': amountMinor,
      'currencyCode': currencyCode,
      'isAnonymous': isAnonymous,
      'supportMessage': supportMessage,
      'paymentMethodLabel': paymentMethodLabel,
      'status': status.name,
      'consentAccepted': consentAccepted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'intentId': intentId,
      'intentPublicId': intentPublicId,
      'referenceId': referenceId,
      'provider': provider,
      'redirectUrl': redirectUrl,
      'expiresAt': expiresAt?.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String(),
      'failure': failure == null
          ? null
          : <String, dynamic>{
              'type': failure!.type.name,
              'code': failure!.code,
              'message': failure!.message,
            },
    };
  }

  factory FundraisingDonationCheckoutRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    final failureJson = json['failure'];
    return FundraisingDonationCheckoutRecord(
      attemptId: json['attemptId']?.toString() ?? '',
      campaignId: fundraisingInt(json['campaignId']) ?? 0,
      campaignTitle: json['campaignTitle']?.toString() ?? '',
      amountMinor: _parseInt(json['amountMinor']),
      currencyCode: json['currencyCode']?.toString() ?? 'BDT',
      isAnonymous: json['isAnonymous'] == true,
      supportMessage: json['supportMessage']?.toString() ?? '',
      paymentMethodLabel: json['paymentMethodLabel']?.toString() ?? '',
      status: _statusFromName(json['status']?.toString()),
      consentAccepted: json['consentAccepted'] == true,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
      intentId: fundraisingInt(json['intentId']),
      intentPublicId: json['intentPublicId']?.toString(),
      referenceId: json['referenceId']?.toString(),
      provider: json['provider']?.toString(),
      redirectUrl: json['redirectUrl']?.toString(),
      expiresAt: _parseDate(json['expiresAt']),
      confirmedAt: _parseDate(json['confirmedAt']),
      failure: failureJson is Map
          ? FundraisingDonationFailure(
              type: _errorTypeFromName(failureJson['type']?.toString()),
              code: failureJson['code']?.toString(),
              message: failureJson['message']?.toString(),
            )
          : null,
    );
  }

  String encode() => jsonEncode(toJson());

  static FundraisingDonationCheckoutRecord decode(String raw) {
    return FundraisingDonationCheckoutRecord.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
}

String? _firstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDate(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}

FundraisingDonationCheckoutStatus _statusFromName(String? raw) {
  return FundraisingDonationCheckoutStatus.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => FundraisingDonationCheckoutStatus.created,
  );
}

FundraisingDonationErrorType _errorTypeFromName(String? raw) {
  return FundraisingDonationErrorType.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => FundraisingDonationErrorType.unknown,
  );
}
