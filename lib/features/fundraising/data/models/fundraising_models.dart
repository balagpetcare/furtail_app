import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:furtail_app/core/media/media_url.dart';

import '../services/fundraising_json.dart';

class FundraisingAccountParseException implements Exception {
  const FundraisingAccountParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

List<String> _sortedJsonKeys(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return keys;
  }
  return const <String>[];
}

Never _throwFundraisingParseException({
  required String parserName,
  required String fieldPath,
  required Object? receivedValue,
  required String expected,
  List<String>? topLevelKeys,
  List<String>? documentKeys,
  List<String>? mediaKeys,
}) {
  final actualType = receivedValue == null
      ? 'Null'
      : receivedValue.runtimeType.toString();
  if (kDebugMode) {
    developer.log(
      'Fundraising parser failure: '
      'parser=$parserName '
      'field=$fieldPath '
      'actualType=$actualType '
      'topLevelKeys=${topLevelKeys == null || topLevelKeys.isEmpty ? 'n/a' : '[${topLevelKeys.join(', ')}]'} '
      'documentKeys=${documentKeys == null || documentKeys.isEmpty ? 'n/a' : '[${documentKeys.join(', ')}]'} '
      'mediaKeys=${mediaKeys == null || mediaKeys.isEmpty ? 'n/a' : '[${mediaKeys.join(', ')}]'} '
      'exceptionType=FundraisingAccountParseException',
      name: 'Fundraising',
    );
  }
  throw FundraisingAccountParseException(
    '$parserName.$fieldPath expected $expected but received $actualType.',
  );
}

String? _readOptionalAccountType(
  Object? value, {
  required String parserName,
  required String fieldPath,
  required List<String> topLevelKeys,
}) {
  final raw = (value?.toString() ?? '').trim().toUpperCase();
  if (raw.isEmpty) return null;
  const allowed = <String>{'INDIVIDUAL', 'ORGANIZATION'};
  if (!allowed.contains(raw)) {
    if (kDebugMode) {
      developer.log(
        'Unexpected fundraising parser value: '
        'parser=$parserName '
        'field=$fieldPath '
        'actualType=${value == null ? 'Null' : value.runtimeType} '
        'topLevelKeys=[${topLevelKeys.join(', ')}] '
        'exceptionType=FundraisingAccountParseException',
        name: 'Fundraising',
      );
    }
    return null;
  }
  return raw;
}

class FundraisingAuthor {
  final int id;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  const FundraisingAuthor({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });

  factory FundraisingAuthor.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] is Map)
        ? Map<String, dynamic>.from(json['profile'])
        : const <String, dynamic>{};
    final avatarMedia = (profile['avatarMedia'] is Map)
        ? Map<String, dynamic>.from(profile['avatarMedia'])
        : const <String, dynamic>{};
    return FundraisingAuthor(
      id: fundraisingInt(json['id']) ?? 0,
      displayName: (profile['displayName'] ?? 'Furtail Member').toString(),
      username: profile['username']?.toString(),
      avatarUrl: (() {
        final u = avatarMedia['url']?.toString() ?? '';
        if (u.trim().isEmpty) return null;
        return MediaUrl.normalize(u);
      })(),
    );
  }
}

class FundraisingMediaItem {
  final int id;
  final String url;
  final String type;

  const FundraisingMediaItem({
    required this.id,
    required this.url,
    required this.type,
  });

  factory FundraisingMediaItem.fromJson(Map<String, dynamic> json) {
    return FundraisingMediaItem(
      id: fundraisingInt(json['id']) ?? 0,
      url: MediaUrl.normalize((json['url'] ?? '').toString()),
      type: (json['type'] ?? '').toString(),
    );
  }
}

class FundraisingStats {
  final int raisedAmount;
  final int withdrawnAmount;
  final int donorsCount;

  const FundraisingStats({
    required this.raisedAmount,
    required this.withdrawnAmount,
    required this.donorsCount,
  });

  factory FundraisingStats.fromJson(Map<String, dynamic> json) {
    return FundraisingStats(
      raisedAmount: fundraisingInt(json['raisedAmount']) ?? 0,
      withdrawnAmount: fundraisingInt(json['withdrawnAmount']) ?? 0,
      donorsCount: fundraisingInt(json['donorsCount']) ?? 0,
    );
  }

  int get availableAmount {
    final amount = raisedAmount - withdrawnAmount;
    return amount < 0 ? 0 : amount;
  }
}

class FundraisingDonor {
  final int id;
  final String name;
  final String? avatarUrl;
  final int? amount;

  const FundraisingDonor({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.amount,
  });

  factory FundraisingDonor.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] is Map)
        ? Map<String, dynamic>.from(json['profile'])
        : const <String, dynamic>{};
    final avatarMedia = (profile['avatarMedia'] is Map)
        ? Map<String, dynamic>.from(profile['avatarMedia'])
        : const <String, dynamic>{};
    return FundraisingDonor(
      id: fundraisingInt(json['id']) ?? 0,
      name: (profile['displayName'] ?? 'Furtail Member').toString(),
      avatarUrl: (() {
        final u = avatarMedia['url']?.toString() ?? '';
        if (u.trim().isEmpty) return null;
        return MediaUrl.normalize(u);
      })(),
      amount: fundraisingInt(json['amount']),
    );
  }
}

class FundraisingAccountDocument {
  final int id;
  final int? accountId;
  final int? mediaId;
  final String title;
  final String documentType;
  final String? mediaUrl;
  final String? mediaType;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  bool get isPrimary => documentType.toUpperCase() == 'PRIMARY';

  const FundraisingAccountDocument({
    required this.id,
    this.accountId,
    this.mediaId,
    required this.title,
    this.documentType = 'SUPPORTING',
    required this.mediaUrl,
    this.mediaType,
    this.createdAt,
    this.deletedAt,
  });

  /// Best-effort file name derived from the media URL, safe to show to the
  /// user (no host/path/query string) — falls back to the document title.
  String get safeFileName {
    final url = mediaUrl;
    if (url == null || url.trim().isEmpty) return title;
    final withoutQuery = url.split('?').first;
    final segments = withoutQuery.split('/');
    final last = segments.isNotEmpty ? segments.last : '';
    return last.trim().isEmpty ? title : last.trim();
  }

  factory FundraisingAccountDocument.fromJson(
    Map<String, dynamic> json, {
    String fieldPathPrefix = 'FundraisingAccountDocument',
    List<String>? topLevelKeys,
  }) {
    final keys = topLevelKeys ?? _sortedJsonKeys(json);
    final media = (json['media'] is Map)
        ? Map<String, dynamic>.from(json['media'] as Map)
        : const <String, dynamic>{};
    final mediaKeys = _sortedJsonKeys(media);

    final id = FundraisingAccount._readInt(json['id']);
    if (id == null) {
      _throwFundraisingParseException(
        parserName: 'FundraisingAccountDocument',
        fieldPath: '$fieldPathPrefix.id',
        receivedValue: json['id'],
        expected: 'numeric document id',
        topLevelKeys: keys,
        documentKeys: _sortedJsonKeys(json),
        mediaKeys: mediaKeys,
      );
    }

    final mediaId = FundraisingAccount._readInt(json['mediaId']);
    if (json.containsKey('mediaId') && mediaId == null) {
      _throwFundraisingParseException(
        parserName: 'FundraisingAccountDocument',
        fieldPath: '$fieldPathPrefix.mediaId',
        receivedValue: json['mediaId'],
        expected: 'numeric media id',
        topLevelKeys: keys,
        documentKeys: _sortedJsonKeys(json),
        mediaKeys: mediaKeys,
      );
    }

    final accountId = FundraisingAccount._readInt(json['accountId']);
    if (json.containsKey('accountId') && accountId == null) {
      _throwFundraisingParseException(
        parserName: 'FundraisingAccountDocument',
        fieldPath: '$fieldPathPrefix.accountId',
        receivedValue: json['accountId'],
        expected: 'numeric account id',
        topLevelKeys: keys,
        documentKeys: _sortedJsonKeys(json),
        mediaKeys: mediaKeys,
      );
    }

    final deletedAt = FundraisingAccount._readDateTime(
      json['deletedAt'],
      parserName: 'FundraisingAccountDocument',
      fieldPath: '$fieldPathPrefix.deletedAt',
      topLevelKeys: keys,
    );
    final createdAt = FundraisingAccount._readDateTime(
      json['createdAt'],
      parserName: 'FundraisingAccountDocument',
      fieldPath: '$fieldPathPrefix.createdAt',
      topLevelKeys: keys,
    );
    final title =
        FundraisingAccount._readString(json['title']) ??
        'Verification document';
    final documentType =
        FundraisingAccount._readString(json['documentType']) ?? 'SUPPORTING';
    final u = FundraisingAccount._readString(media['url']);
    final mediaType = FundraisingAccount._readString(media['type']);
    return FundraisingAccountDocument(
      id: id,
      accountId: accountId,
      mediaId: mediaId,
      title: title,
      documentType: documentType,
      mediaUrl: u == null ? null : MediaUrl.normalize(u),
      mediaType: mediaType,
      createdAt: createdAt,
      deletedAt: deletedAt,
    );
  }
}

class FundraisingAccount {
  final int id;
  final String status; // DRAFT/PENDING/VERIFIED/REJECTED
  final String? accountType; // INDIVIDUAL/ORGANIZATION
  final String? fullName;
  final String? presentAddress;
  final String? permanentAddress;
  final String? occupation;
  final bool isInternational;
  final int? divisionId;
  final int? districtId;
  final int? upazilaId;
  final int? unionId;
  final int? areaId;
  final DateTime? dateOfBirth;
  final String? primaryDocumentType;
  final String? nationalIdNumber;
  final String? birthRegNumber;
  final String? studentIdNumber;
  final String? passportNumber;
  final String? drivingLicenceNumber;
  final Map<String, dynamic>? verificationDraftJson;
  final String? area;
  final int? rescueSinceYear;
  final String? orgName;
  final String? orgDescription;
  final String? orgWorkType;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final List<FundraisingAccountDocument> documents;

  // Global location (Phase 5)
  final String? countryCode;
  final String? countryName;
  final String? stateName;
  final String? cityName;
  final String? addressLine;
  final double? latitude;
  final double? longitude;
  final String? formattedAddress;

  const FundraisingAccount({
    required this.id,
    required this.status,
    required this.accountType,
    this.fullName,
    required this.presentAddress,
    required this.permanentAddress,
    required this.occupation,
    this.isInternational = false,
    required this.divisionId,
    required this.districtId,
    required this.upazilaId,
    required this.unionId,
    required this.areaId,
    required this.dateOfBirth,
    this.primaryDocumentType,
    required this.nationalIdNumber,
    required this.birthRegNumber,
    required this.studentIdNumber,
    this.passportNumber,
    this.drivingLicenceNumber,
    this.verificationDraftJson,
    required this.area,
    required this.rescueSinceYear,
    required this.orgName,
    required this.orgDescription,
    required this.orgWorkType,
    this.rejectionReason,
    required this.submittedAt,
    required this.documents,
    this.countryCode,
    this.countryName,
    this.stateName,
    this.cityName,
    this.addressLine,
    this.latitude,
    this.longitude,
    this.formattedAddress,
  });

  factory FundraisingAccount.fromJson(Map<String, dynamic> json) {
    final topLevelKeys = _sortedJsonKeys(json);
    final payload = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final id = _requiredInt(
      payload,
      'id',
      parserName: 'FundraisingAccount',
      topLevelKeys: topLevelKeys,
    );
    final status = _normalizedStatus(payload['status']);
    final accountType = _readOptionalAccountType(
      payload['accountType'],
      parserName: 'FundraisingAccount',
      fieldPath: 'accountType',
      topLevelKeys: topLevelKeys,
    );

    final docsRaw = payload['documents'];
    final docs = <FundraisingAccountDocument>[];
    if (docsRaw == null) {
      // Missing is valid for first-time setup.
    } else if (docsRaw is List) {
      for (var index = 0; index < docsRaw.length; index += 1) {
        final entry = docsRaw[index];
        if (entry is Map) {
          try {
            docs.add(
              FundraisingAccountDocument.fromJson(
                Map<String, dynamic>.from(entry),
                fieldPathPrefix: 'FundraisingAccount.documents[$index]',
                topLevelKeys: topLevelKeys,
              ),
            );
          } on FundraisingAccountParseException {
            continue;
          }
        } else if (entry != null) {
          if (kDebugMode) {
            developer.log(
              'Fundraising parser failure: '
              'parser=FundraisingAccount '
              'field=documents[$index] '
              'actualType=${entry.runtimeType} '
              'topLevelKeys=[${topLevelKeys.join(', ')}] '
              'documentKeys=[${_sortedJsonKeys(entry).join(', ')}] '
              'mediaKeys=n/a '
              'exceptionType=FundraisingAccountParseException',
              name: 'Fundraising',
            );
          }
        }
      }
    } else {
      _throwFundraisingParseException(
        parserName: 'FundraisingAccount',
        fieldPath: 'documents',
        receivedValue: docsRaw,
        expected: 'a list of verification documents',
        topLevelKeys: topLevelKeys,
        documentKeys: _sortedJsonKeys(docsRaw),
      );
    }

    return FundraisingAccount(
      id: id,
      status: status,
      accountType: accountType,
      fullName: _readString(payload['fullName']),
      presentAddress: _readString(payload['presentAddress']),
      permanentAddress: _readString(payload['permanentAddress']),
      occupation: _readString(payload['occupation']),
      isInternational: payload['isInternational'] == true,
      divisionId: _readInt(payload['divisionId']),
      districtId: _readInt(payload['districtId']),
      upazilaId: _readInt(payload['upazilaId']),
      unionId: _readInt(payload['unionId']),
      areaId: _readInt(payload['areaId']),
      dateOfBirth: _readDateOnly(payload['dateOfBirth']),
      primaryDocumentType: _readString(payload['primaryDocumentType']),
      nationalIdNumber: _readString(payload['nationalIdNumber']),
      birthRegNumber: _readString(payload['birthRegNumber']),
      studentIdNumber: _readString(payload['studentIdNumber']),
      passportNumber: _readString(payload['passportNumber']),
      drivingLicenceNumber: _readString(payload['drivingLicenceNumber']),
      verificationDraftJson: payload['verificationDraftJson'] is Map
          ? Map<String, dynamic>.from(payload['verificationDraftJson'] as Map)
          : null,
      area: _readString(payload['area']),
      rescueSinceYear: _readInt(payload['rescueSinceYear']),
      orgName: _readString(payload['orgName']),
      orgDescription: _readString(payload['orgDescription']),
      orgWorkType: _readString(payload['orgWorkType']),
      rejectionReason:
          _readString(payload['rejectionReason']) ??
          _readString(payload['rejectionMessage']) ??
          _readString(payload['rejectionNote']),
      submittedAt: _readDateTime(
        payload['submittedAt'],
        parserName: 'FundraisingAccount',
        fieldPath: 'submittedAt',
        topLevelKeys: topLevelKeys,
      ),
      documents: docs,
      countryCode: _readString(payload['countryCode']),
      countryName: _readString(payload['countryName']),
      stateName: _readString(payload['stateName']),
      cityName: _readString(payload['cityName']),
      addressLine: _readString(payload['addressLine']),
      latitude: _readDouble(payload['latitude']),
      longitude: _readDouble(payload['longitude']),
      formattedAddress: _readString(payload['formattedAddress']),
    );
  }

  static int _requiredInt(
    Map<String, dynamic> json,
    String key, {
    required String parserName,
    required List<String> topLevelKeys,
  }) {
    final value = _readInt(json[key]);
    if (value == null) {
      _throwFundraisingParseException(
        parserName: parserName,
        fieldPath: key,
        receivedValue: json[key],
        expected: 'numeric value',
        topLevelKeys: topLevelKeys,
      );
    }
    return value;
  }

  static String _normalizedStatus(Object? value) {
    final raw = (value?.toString() ?? '').trim().toUpperCase();
    // Only PENDING, VERIFIED, and REJECTED are valid Prisma enum values
    const allowed = <String>{'PENDING', 'VERIFIED', 'REJECTED'};
    if (raw.isEmpty) {
      return 'PENDING'; // Default to PENDING for new accounts
    }
    if (!allowed.contains(raw)) {
      if (kDebugMode) {
        developer.log(
          'Unexpected fundraising account status: $raw (not in Prisma enum)',
          name: 'Fundraising',
        );
      }
      return 'PENDING'; // Fallback to PENDING for unknown values
    }
    return raw;
  }

  static int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static double? _readDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static String? _readString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Parses a canonical YYYY-MM-DD date-only value into a local-midnight
  /// [DateTime]. Deliberately does not call [DateTime.parse]/[DateTime.tryParse]
  /// on the raw string for this field: those treat a bare `YYYY-MM-DD` string
  /// as UTC, which can render as the previous day once converted to the
  /// device's local timezone. Parsing the components manually and
  /// constructing a local [DateTime] keeps the selected calendar day stable.
  static DateTime? _readDateOnly(Object? value) {
    final text = _readString(value);
    if (text == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static DateTime? _readDateTime(
    Object? value, {
    required String parserName,
    required String fieldPath,
    required List<String> topLevelKeys,
  }) {
    final text = _readString(value);
    if (text == null) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      _throwFundraisingParseException(
        parserName: parserName,
        fieldPath: fieldPath,
        receivedValue: value,
        expected: 'ISO-8601 date value',
        topLevelKeys: topLevelKeys,
      );
    }
    return parsed;
  }

  bool get isVerified => status.toUpperCase() == 'VERIFIED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  FundraisingAccountReadiness get readiness =>
      FundraisingAccountReadiness.fromAccount(this);
}

class FundraisingAccountReadiness {
  final bool accountExists;
  final String status;
  final bool requiredProfileComplete;
  final bool requiredDocumentsUploaded;
  final bool statusNotRejectedOrBlocked;
  final bool isPendingReview;
  final bool isRejected;
  final List<String> missingProfileFields;
  final List<String> missingDocumentTypes;
  final String? safeRejectionReason;

  const FundraisingAccountReadiness({
    required this.accountExists,
    required this.status,
    required this.requiredProfileComplete,
    required this.requiredDocumentsUploaded,
    required this.statusNotRejectedOrBlocked,
    required this.isPendingReview,
    required this.isRejected,
    required this.missingProfileFields,
    required this.missingDocumentTypes,
    required this.safeRejectionReason,
  });

  bool get canStartFundraiser =>
      requiredProfileComplete &&
      requiredDocumentsUploaded &&
      statusNotRejectedOrBlocked;

  bool get requiresVerificationRoute => !canStartFundraiser;

  factory FundraisingAccountReadiness.fromAccount(FundraisingAccount? account) {
    final normalizedStatus = (account?.status ?? 'PENDING').toUpperCase();
    // Only PENDING, VERIFIED, and REJECTED are valid Prisma enum values
    final isRejected = normalizedStatus == 'REJECTED';
    final isPending = normalizedStatus == 'PENDING';
    final isVerified = normalizedStatus == 'VERIFIED';
    final hasAccount = account != null;
    final missingProfileFields = <String>[];

    if (account == null || (account.fullName ?? '').trim().isEmpty) {
      missingProfileFields.add('fullName');
    }
    if (account == null || (account.presentAddress ?? '').trim().isEmpty) {
      missingProfileFields.add('presentAddress');
    }
    if (account == null || (account.permanentAddress ?? '').trim().isEmpty) {
      missingProfileFields.add('permanentAddress');
    }
    if (!_hasVerificationLocation(account)) {
      missingProfileFields.add('location');
    }
    if (account == null || account.dateOfBirth == null) {
      missingProfileFields.add('dateOfBirth');
    }
    if (account == null || !_hasPrimaryIdentityNumber(account)) {
      missingProfileFields.add('primaryDocumentNumber');
    }

    final hasRequiredDocuments = _hasPrimaryVerificationDocument(
      account?.documents ?? const <FundraisingAccountDocument>[],
    );

    return FundraisingAccountReadiness(
      accountExists: hasAccount,
      status: normalizedStatus,
      requiredProfileComplete: missingProfileFields.isEmpty,
      requiredDocumentsUploaded: hasRequiredDocuments,
      statusNotRejectedOrBlocked: !isRejected,
      isPendingReview: isPending || isVerified,
      isRejected: isRejected,
      missingProfileFields: missingProfileFields,
      missingDocumentTypes: hasRequiredDocuments
          ? const <String>[]
          : const <String>['required_verification_document'],
      safeRejectionReason: isRejected
          ? (account?.rejectionReason?.trim().isNotEmpty == true
                ? account!.rejectionReason!.trim()
                : 'Your fundraising verification was rejected. Review the feedback and update your information.')
          : null,
    );
  }

  /// A Bangladesh location is complete at division/district/upazila/union —
  /// area is always optional, even when the selected union has no areas.
  static bool _hasVerificationLocation(FundraisingAccount? account) {
    if (account == null) return false;
    if (account.isInternational) {
      final hasCountry =
          (account.countryCode ?? '').trim().isNotEmpty ||
          (account.countryName ?? '').trim().isNotEmpty;
      final hasCity = (account.cityName ?? '').trim().isNotEmpty;
      final hasAddress =
          (account.addressLine ?? '').trim().isNotEmpty ||
          (account.formattedAddress ?? '').trim().isNotEmpty;
      return hasCountry && hasCity && hasAddress;
    }
    return account.divisionId != null &&
        account.districtId != null &&
        account.upazilaId != null &&
        account.unionId != null;
  }

  static bool _hasPrimaryIdentityNumber(FundraisingAccount account) {
    final selected = (account.primaryDocumentType ?? '').trim().toUpperCase();
    if (selected.isEmpty) return false;
    String? numberFor(String type) {
      switch (type) {
        case 'NID':
        case 'NATIONAL_ID':
          return account.nationalIdNumber;
        case 'BIRTH REGISTRATION':
        case 'BIRTH_REGISTRATION':
        case 'BIRTHREG':
        case 'BIRTH':
          return account.birthRegNumber;
        case 'PASSPORT':
          return account.passportNumber;
        case 'SCHOOL/COLLEGE ID':
        case 'STUDENT ID':
        case 'STUDENT_ID':
          return account.studentIdNumber;
        case 'DRIVING_LICENCE':
        case 'DRIVING LICENCE':
        case 'DRIVING':
          return account.drivingLicenceNumber;
        default:
          return null;
      }
    }

    return (numberFor(selected) ?? '').trim().isNotEmpty;
  }

  static bool _hasPrimaryVerificationDocument(
    List<FundraisingAccountDocument> documents,
  ) {
    return documents.any((document) => document.isPrimary);
  }
}

class FundraisingCampaign {
  final int id;
  final int postId;
  final String title;
  final int targetAmount;
  final int? targetAmountMinor;
  final int? monthlyGoalMinor;
  final String fundingMode;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? deadline;
  final DateTime? nextReviewAt;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final String status;
  final FundraisingAuthor author;
  final String? caption;
  final List<FundraisingMediaItem> media;
  final FundraisingStats stats;
  final bool isAccountVerified;
  final bool? donationAllowed;
  final String? category;
  final String? locationText;
  final List<FundraisingDonor> last3Donors;

  const FundraisingCampaign({
    required this.id,
    required this.postId,
    required this.title,
    required this.targetAmount,
    this.targetAmountMinor,
    this.monthlyGoalMinor,
    required this.fundingMode,
    this.startsAt,
    this.endsAt,
    required this.deadline,
    this.nextReviewAt,
    this.publishedAt,
    required this.createdAt,
    required this.status,
    required this.author,
    required this.caption,
    required this.media,
    required this.stats,
    required this.isAccountVerified,
    this.donationAllowed,
    required this.category,
    required this.locationText,
    required this.last3Donors,
  });

  factory FundraisingCampaign.fromJson(Map<String, dynamic> json) {
    final creator = (json['creator'] is Map)
        ? Map<String, dynamic>.from(json['creator'])
        : const <String, dynamic>{};
    final post = (json['post'] is Map)
        ? Map<String, dynamic>.from(json['post'])
        : const <String, dynamic>{};
    final authorJson = (post['author'] is Map)
        ? Map<String, dynamic>.from(post['author'])
        : creator.isNotEmpty
        ? <String, dynamic>{
            'id': 0,
            'profile': <String, dynamic>{
              'displayName': creator['displayName'],
              'username': creator['username'],
              'avatarMedia': <String, dynamic>{'url': creator['avatarUrl']},
            },
          }
        : const <String, dynamic>{};
    final statsJson = (json['stats'] is Map)
        ? Map<String, dynamic>.from(json['stats'])
        : <String, dynamic>{
            'raisedAmount':
                json['raisedAmountMinor'] ?? json['raisedAmount'] ?? 0,
            'withdrawnAmount': 0,
            'donorsCount': json['donorsCount'] ?? 0,
          };
    final account = (json['account'] is Map)
        ? Map<String, dynamic>.from(json['account'])
        : const <String, dynamic>{};

    final last3 = (json['last3Donors'] as List?) ?? const [];
    final last3Donors = last3
        .whereType<Map>()
        .map((e) => FundraisingDonor.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final mediaRaw = (post['media'] as List?) ?? const [];
    final media = mediaRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((pm) {
          final m = (pm['media'] is Map)
              ? Map<String, dynamic>.from(pm['media'])
              : const <String, dynamic>{};
          return FundraisingMediaItem.fromJson(m);
        })
        .toList();
    if (media.isEmpty) {
      final coverMediaUrl = json['coverMediaUrl']?.toString().trim();
      if (coverMediaUrl != null && coverMediaUrl.isNotEmpty) {
        media.add(
          FundraisingMediaItem(
            id: 0,
            url: MediaUrl.normalize(coverMediaUrl),
            type: 'IMAGE',
          ),
        );
      }
    }

    DateTime? startsAt;
    final startsAtRaw = json['startsAt']?.toString();
    if (startsAtRaw != null && startsAtRaw.isNotEmpty) {
      startsAt = DateTime.tryParse(startsAtRaw);
    }

    DateTime? endsAt;
    final endsAtRaw = json['endsAt']?.toString();
    if (endsAtRaw != null && endsAtRaw.isNotEmpty) {
      endsAt = DateTime.tryParse(endsAtRaw);
    }

    DateTime? deadline;
    final dl = json['deadline']?.toString();
    if (dl != null && dl.isNotEmpty) {
      deadline = DateTime.tryParse(dl);
    }
    deadline ??= endsAt;
    endsAt ??= deadline;

    DateTime? nextReviewAt;
    final nextReviewRaw = json['nextReviewAt']?.toString();
    if (nextReviewRaw != null && nextReviewRaw.isNotEmpty) {
      nextReviewAt = DateTime.tryParse(nextReviewRaw);
    }

    final createdAtRaw =
        post['createdAt']?.toString() ?? json['publishedAt']?.toString();
    final createdAt = (createdAtRaw != null && createdAtRaw.isNotEmpty)
        ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
        : DateTime.now();
    final publishedAtRaw = json['publishedAt']?.toString();
    final publishedAt = (publishedAtRaw != null && publishedAtRaw.isNotEmpty)
        ? DateTime.tryParse(publishedAtRaw)
        : null;

    return FundraisingCampaign(
      id: fundraisingInt(json['id']) ?? 0,
      postId: fundraisingInt(post['id']) ?? 0,
      title: (json['title'] ?? 'Campaign').toString(),
      targetAmount:
          fundraisingInt(json['targetAmountMinor']) ??
          fundraisingInt(json['targetAmount']) ??
          0,
      targetAmountMinor: fundraisingInt(json['targetAmountMinor']),
      monthlyGoalMinor: fundraisingInt(json['monthlyGoalMinor']),
      fundingMode: (json['fundingMode'] ?? 'ONE_TIME').toString(),
      startsAt: startsAt,
      endsAt: endsAt,
      deadline: deadline,
      nextReviewAt: nextReviewAt,
      publishedAt: publishedAt,
      createdAt: createdAt,
      status: (json['status'] ?? 'ACTIVE').toString(),
      author: FundraisingAuthor.fromJson(authorJson),
      caption: post['caption']?.toString(),
      media: media,
      stats: FundraisingStats.fromJson(statsJson),
      isAccountVerified:
          (account['status']?.toString().toUpperCase() == 'VERIFIED'),
      donationAllowed: fundraisingBool(
        json['donationAllowed'] ??
            json['acceptingDonations'] ??
            json['canDonate'],
      ),
      category: json['category']?.toString(),
      locationText: json['locationText']?.toString(),
      last3Donors: last3Donors,
    );
  }

  int get remainingAmount {
    final canonicalTarget = targetAmountMinor ?? targetAmount;
    final r = canonicalTarget - stats.raisedAmount;
    return r < 0 ? 0 : r;
  }

  bool get isPublished => publishedAt != null;

  bool get isDonationEligible {
    final normalized = status.trim().toUpperCase();
    if (const <String>{
      'DRAFT',
      'REJECTED',
      'CANCELLED',
      'ARCHIVED',
      'SUSPENDED',
      'PAUSED',
      'FUNDED',
      'COMPLETED',
      'EXPIRED',
      'DELETED',
    }.contains(normalized)) {
      return false;
    }
    final effectiveEnd = endsAt ?? deadline;
    if (effectiveEnd != null && effectiveEnd.isBefore(DateTime.now())) {
      return false;
    }

    // Prefer the API's explicit policy flag when present. Older API builds
    // may omit it, so keep a safe status-based fallback that allows public
    // pending-review campaigns to receive donations.
    if (donationAllowed != null) return donationAllowed!;
    return const <String>{
      'PENDING_REVIEW',
      'APPROVED',
      'PUBLISHED',
      'ACTIVE',
    }.contains(normalized);
  }

  String? get donationUnavailableMessage {
    final normalized = status.trim().toUpperCase();
    if (normalized == 'DRAFT') {
      return 'This fundraiser is still a draft.';
    }
    switch (normalized) {
      case 'REJECTED':
        return 'This fundraiser was rejected and cannot receive donations.';
      case 'CANCELLED':
        return 'This fundraiser has been cancelled.';
      case 'ARCHIVED':
        return 'This fundraiser is archived.';
      case 'SUSPENDED':
        return 'This fundraiser is suspended.';
      case 'PAUSED':
        return 'This fundraiser is paused and not accepting donations.';
      case 'FUNDED':
        return 'This fundraiser reached its goal and is not accepting more donations.';
      case 'COMPLETED':
        return 'This fundraiser has been completed.';
      case 'EXPIRED':
        return 'This fundraiser has expired.';
      case 'DELETED':
        return 'This fundraiser is no longer available.';
    }
    final effectiveEnd = endsAt ?? deadline;
    if (effectiveEnd != null && effectiveEnd.isBefore(DateTime.now())) {
      return 'This fundraiser has expired.';
    }
    if (donationAllowed == false) {
      return 'Donations are temporarily unavailable for this fundraiser.';
    }
    return null;
  }

  double get progress {
    final canonicalTarget = targetAmountMinor ?? targetAmount;
    if (canonicalTarget <= 0) return 0;
    final p = stats.raisedAmount / canonicalTarget;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  String? get context => null;

  int? get remainingDays {
    if (deadline == null) return null;
    final now = DateTime.now();
    final d = deadline!;
    final diff = d.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays;
  }
}

class DonationItem {
  final int id;
  final int amount;
  final DateTime createdAt;
  final FundraisingDonor donor;

  const DonationItem({
    required this.id,
    required this.amount,
    required this.createdAt,
    required this.donor,
  });

  factory DonationItem.fromJson(Map<String, dynamic> json) {
    final donorJson = (json['donor'] is Map)
        ? Map<String, dynamic>.from(json['donor'])
        : const <String, dynamic>{};
    final created =
        DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
        DateTime.now();
    return DonationItem(
      id: fundraisingInt(json['id']) ?? 0,
      amount: fundraisingInt(json['amount']) ?? 0,
      createdAt: created,
      donor: FundraisingDonor.fromJson(donorJson),
    );
  }
}

class FundraisingUpdateItem {
  final int id;
  final int postId;
  final DateTime createdAt;
  final String? caption;
  final FundraisingAuthor author;
  final List<FundraisingMediaItem> media;

  const FundraisingUpdateItem({
    required this.id,
    required this.postId,
    required this.createdAt,
    required this.caption,
    required this.author,
    required this.media,
  });

  factory FundraisingUpdateItem.fromJson(Map<String, dynamic> json) {
    final post = (json['post'] is Map)
        ? Map<String, dynamic>.from(json['post'])
        : const <String, dynamic>{};
    final authorJson = (post['author'] is Map)
        ? Map<String, dynamic>.from(post['author'])
        : const <String, dynamic>{};
    final mediaRaw = (post['media'] as List?) ?? const [];
    final media = mediaRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((pm) {
          final m = (pm['media'] is Map)
              ? Map<String, dynamic>.from(pm['media'])
              : const <String, dynamic>{};
          return FundraisingMediaItem.fromJson(m);
        })
        .toList();
    final createdAt =
        DateTime.tryParse(
          (json['createdAt'] ?? post['createdAt'] ?? '').toString(),
        ) ??
        DateTime.now();
    return FundraisingUpdateItem(
      id: fundraisingInt(json['id']) ?? 0,
      postId: fundraisingInt(post['id']) ?? 0,
      createdAt: createdAt,
      caption: post['caption']?.toString(),
      author: FundraisingAuthor.fromJson(authorJson),
      media: media,
    );
  }
}
