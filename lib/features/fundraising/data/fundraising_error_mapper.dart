import 'dart:io';

import 'package:dio/dio.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/services/api_client.dart';

/// Broad category for a mapped fundraising failure, used to decide which
/// friendly UI state (retry card, session-expired, etc.) to render.
enum FundraisingErrorCategory {
  network,
  timeout,
  notFound,
  permissionDenied,
  sessionExpired,
  accountIncomplete,
  accountRejected,
  schemaUnavailable,
  serverFailure,
  validation,
  parseFailure,
  unknown,
}

class FundraisingSafeError {
  const FundraisingSafeError({
    required this.category,
    required this.message,
    this.statusCode,
    this.backendCode,
    this.details,
    this.requestId,
  });

  final FundraisingErrorCategory category;
  final String message;
  final int? statusCode;
  final String? backendCode;
  final Map<String, dynamic>? details;
  final String? requestId;

  bool get isNetwork => category == FundraisingErrorCategory.network;
  bool get isTimeout => category == FundraisingErrorCategory.timeout;
  bool get isNotFound => category == FundraisingErrorCategory.notFound;
  bool get isPermissionDenied =>
      category == FundraisingErrorCategory.permissionDenied;
  bool get isSessionExpired =>
      category == FundraisingErrorCategory.sessionExpired;
  bool get isParseFailure => category == FundraisingErrorCategory.parseFailure;
  bool get isAccountIncomplete =>
      category == FundraisingErrorCategory.accountIncomplete;
  bool get isAccountRejected =>
      category == FundraisingErrorCategory.accountRejected;
  bool get isSchemaUnavailable =>
      category == FundraisingErrorCategory.schemaUnavailable;
  bool get isServerFailure =>
      category == FundraisingErrorCategory.serverFailure;

  List<String>? get missingRequirements {
    if (details case {'missingRequirements': List<dynamic> list}) {
      return list.map((item) => item.toString()).toList();
    }
    return null;
  }
}

/// Centralized user-facing error mapper for fundraising verification /
/// eligibility screens. Converts DioException/ApiClientException/raw
/// exceptions into a safe, concise category + message — never surfacing
/// DioException/SocketException text, stack traces, request URLs, IPs,
/// ports, or raw JSON to the user.
///
/// Checks backend error codes BEFORE HTTP status codes to preserve specific
/// domain-level error information (e.g., account incomplete vs generic 409).
FundraisingSafeError mapFundraisingSafeError(Object error) {
  if (error is FundraisingUserSafeException) {
    return FundraisingSafeError(
      category: FundraisingErrorCategory.unknown,
      message: error.message,
    );
  }

  if (error is FundraisingAccountParseException || error is FormatException) {
    return const FundraisingSafeError(
      category: FundraisingErrorCategory.parseFailure,
      message:
          'We couldn\'t read the server response. Please try again shortly.',
    );
  }

  if (error is ApiClientException) {
    final code = (error.code ?? '').trim().toUpperCase();
    final statusCode = error.statusCode ?? 0;
    final responseData = error.responseData is Map
        ? Map<String, dynamic>.from(error.responseData as Map)
        : null;
    final details = responseData?['details'] is Map
        ? Map<String, dynamic>.from(responseData!['details'] as Map)
        : null;

    // Session/auth failures (check first, regardless of status code)
    if (error.isUnauthorized ||
        code == 'CENTRAL_TOKEN_EXPIRED' ||
        code == 'TOKEN_REVOKED') {
      return FundraisingSafeError(
        category: FundraisingErrorCategory.sessionExpired,
        message: 'Your session has expired. Please sign in again.',
        statusCode: statusCode,
        backendCode: code,
      );
    }

    // Domain-level errors (check specific backend codes BEFORE generic HTTP status)
    switch (code) {
      case 'FUNDRAISING_CAMPAIGN_NOT_FOUND':
      case 'CAMPAIGN_NOT_FOUND':
      case 'CAMPAIGN_DELETED':
        return FundraisingSafeError(
          category: FundraisingErrorCategory.notFound,
          message: 'This fundraiser is unavailable.',
          statusCode: statusCode,
          backendCode: code,
          details: details,
        );

      case 'FUNDRAISING_ACCOUNT_INCOMPLETE':
        return FundraisingSafeError(
          category: FundraisingErrorCategory.accountIncomplete,
          message:
              'Complete your fundraising profile before creating a fundraiser.',
          statusCode: statusCode,
          backendCode: code,
          details: details,
        );

      case 'FUNDRAISING_FORBIDDEN':
        return FundraisingSafeError(
          category: FundraisingErrorCategory.permissionDenied,
          message:
              (responseData?['message']?.toString()) ??
              'Your fundraising account is restricted. Please contact support.',
          statusCode: statusCode,
          backendCode: code,
          details: details,
        );

      case 'FUNDRAISING_SCHEMA_UNAVAILABLE':
        return FundraisingSafeError(
          category: FundraisingErrorCategory.schemaUnavailable,
          message:
              'Fundraising is temporarily unavailable. Please try again shortly.',
          statusCode: statusCode,
          backendCode: code,
        );

      case 'FUNDRAISING_REQUEST_FAILED':
        return FundraisingSafeError(
          category: FundraisingErrorCategory.serverFailure,
          message:
              'The fundraising service could not complete the request. Please try again.',
          statusCode: statusCode,
          backendCode: code,
        );

      case 'FUNDRAISING_DRAFT_SAVE_FAILED':
        return FundraisingSafeError(
          category: FundraisingErrorCategory.serverFailure,
          message: 'We could not save this draft right now. Please try again.',
          statusCode: statusCode,
          backendCode: code,
        );
    }

    // Network errors
    if (error.isNetworkError) {
      return FundraisingSafeError(
        category:
            error.dioExceptionType == 'connectionTimeout' ||
                error.dioExceptionType == 'receiveTimeout' ||
                error.dioExceptionType == 'sendTimeout'
            ? FundraisingErrorCategory.timeout
            : FundraisingErrorCategory.network,
        message:
            'Unable to connect. Check your internet connection and make sure the service is available, then try again.',
        statusCode: statusCode,
        backendCode: code.isEmpty ? null : code,
      );
    }

    if (statusCode == 404) {
      return FundraisingSafeError(
        category: FundraisingErrorCategory.notFound,
        message: 'This fundraiser is unavailable.',
        statusCode: statusCode,
        backendCode: code.isEmpty ? null : code,
      );
    }

    // Now check generic HTTP status codes (after checking specific backend codes)
    if (statusCode >= 500) {
      return FundraisingSafeError(
        category: FundraisingErrorCategory.serverFailure,
        message:
            'The service is temporarily unavailable. Please try again shortly.',
        statusCode: statusCode,
        backendCode: code.isEmpty ? null : code,
      );
    }

    if (statusCode == 400 || statusCode == 422) {
      return FundraisingSafeError(
        category: FundraisingErrorCategory.validation,
        message: mapFundraisingError(error),
        statusCode: statusCode,
        backendCode: code.isEmpty ? null : code,
        details: details,
      );
    }

    if (statusCode == 403) {
      return FundraisingSafeError(
        category: FundraisingErrorCategory.permissionDenied,
        message:
            (responseData?['message']?.toString()) ??
            'You do not have permission to view this fundraiser.',
        statusCode: statusCode,
        backendCode: code.isEmpty ? null : code,
        details: details,
      );
    }

    // Fallback for any other error
    return FundraisingSafeError(
      category: FundraisingErrorCategory.unknown,
      message: mapFundraisingError(error),
      statusCode: statusCode,
      backendCode: code.isEmpty ? null : code,
    );
  }

  if (error is TypeError || error is ArgumentError) {
    return const FundraisingSafeError(
      category: FundraisingErrorCategory.parseFailure,
      message:
          'We couldn\'t read the server response. Please try again shortly.',
    );
  }

  // Defensive: these should already be wrapped as ApiClientException by
  // ApiClient, but never let a raw exception type leak its message.
  if (error is DioException || error is SocketException) {
    return const FundraisingSafeError(
      category: FundraisingErrorCategory.network,
      message:
          'Unable to connect. Check your internet connection and make sure the service is available, then try again.',
    );
  }

  return const FundraisingSafeError(
    category: FundraisingErrorCategory.unknown,
    message: 'Something went wrong. Please try again.',
  );
}

/// Shared, code-first title for a mapped fundraising failure. Every fundraising
/// screen (create, verification setup, documents) uses this so a recognized
/// domain error is never flattened into a generic "unavailable" heading.
String fundraisingErrorTitle(FundraisingSafeError? error) {
  switch (error?.category) {
    case FundraisingErrorCategory.network:
      return 'Unable to connect';
    case FundraisingErrorCategory.timeout:
      return 'Request timed out';
    case FundraisingErrorCategory.notFound:
      return 'Fundraiser unavailable';
    case FundraisingErrorCategory.permissionDenied:
      return 'Permission denied';
    case FundraisingErrorCategory.sessionExpired:
      return 'Session expired';
    case FundraisingErrorCategory.accountIncomplete:
      return 'Complete your fundraising profile';
    case FundraisingErrorCategory.accountRejected:
      return 'Fundraising account rejected';
    case FundraisingErrorCategory.schemaUnavailable:
      return 'Fundraising is temporarily unavailable';
    case FundraisingErrorCategory.serverFailure:
      return 'We could not complete this request';
    case FundraisingErrorCategory.parseFailure:
      return "We couldn't read the server response";
    case FundraisingErrorCategory.validation:
      return 'Please check your information';
    case FundraisingErrorCategory.unknown:
    case null:
      return 'Something went wrong';
  }
}

/// Shared description. For an incomplete account it renders the backend's
/// `details.missingRequirements` as readable, actionable bullets instead of the
/// raw field keys.
String fundraisingErrorDescription(FundraisingSafeError? error) {
  if (error == null) return '';
  if (error.category == FundraisingErrorCategory.notFound) {
    return 'This fundraiser is no longer available.';
  }
  if (error.category == FundraisingErrorCategory.permissionDenied) {
    return 'You do not have permission to view this fundraiser.';
  }
  if (error.category == FundraisingErrorCategory.accountIncomplete) {
    final formatted = formatFundraisingMissingRequirements(
      error.missingRequirements ?? const <String>[],
    );
    if (formatted.isNotEmpty) {
      return 'You need to:\n• ${formatted.join('\n• ')}';
    }
  }
  return error.message;
}

/// Converts backend requirement keys into readable actions. Unknown keys are
/// dropped rather than leaked raw, and repeated labels (the several location
/// keys all map to one action) are emitted only once.
List<String> formatFundraisingMissingRequirements(List<String> requirements) {
  final formatted = <String>[];
  for (final requirement in requirements) {
    final label = switch (requirement.toLowerCase()) {
      'presentaddress' => 'Complete your present address',
      'permanentaddress' => 'Complete your permanent address',
      'dateofbirth' => 'Add your date of birth',
      'location' ||
      'divisionid' ||
      'districtid' ||
      'upazilaid' ||
      'unionid' ||
      'areaid' => 'Add your location',
      'documents' ||
      'verification_documents' => 'Upload a verification document',
      'occupation' => 'Add your occupation',
      'area' => 'Specify your area',
      'accounttype' => 'Select your account type',
      'verification_profile' => 'Complete your verification profile',
      _ => null,
    };
    if (label != null && !formatted.contains(label)) {
      formatted.add(label);
    }
  }
  return formatted;
}

/// Extracts the first field-level message from a `FUNDRAISING_VALIDATION_ERROR`
/// response's `details: [{path, message}, ...]` payload, so the UI can show
/// exactly what's wrong instead of a generic fallback. Returns `null` when
/// there's no usable per-field detail (falls back to the generic message).
String? fundraisingValidationDetailMessage(ApiClientException error) {
  final data = error.responseData;
  if (data is! Map) return null;
  final details = data['details'];
  if (details is! List || details.isEmpty) return null;
  final first = details.first;
  if (first is! Map) return null;
  final message = first['message']?.toString().trim();
  return (message == null || message.isEmpty) ? null : message;
}

class FundraisingUserSafeException implements Exception {
  final String message;

  const FundraisingUserSafeException(this.message);

  @override
  String toString() => message;
}

String mapFundraisingError(Object error) {
  if (error is FundraisingUserSafeException) {
    return error.message;
  }
  if (error is ApiClientException) {
    final code = (error.code ?? '').trim().toUpperCase();
    switch (code) {
      case 'FUNDRAISING_SCHEMA_UNAVAILABLE':
        return 'Fundraising is temporarily unavailable. Please try again shortly.';
      case 'FUNDRAISING_DRAFT_SAVE_FAILED':
        return 'We could not save this draft right now. Please try again.';
      case 'FUNDRAISING_ACCOUNT_INCOMPLETE':
        return 'Complete your verification profile before saving a draft.';
      case 'FUNDRAISING_REAUTH_REQUIRED':
        return 'For security, please sign in again before changing payout details or submitting a withdrawal.';
      case 'FUNDRAISING_PAYOUT_DUPLICATE':
        return 'This payout method is already on file.';
      case 'FUNDRAISING_PAYOUT_DETAILS_REQUIRED':
        return 'Please complete the required payout details.';
      case 'FUNDRAISING_WITHDRAWAL_ALREADY_PENDING':
        return 'You already have a withdrawal under review for this campaign.';
      case 'FUNDRAISING_WITHDRAWAL_INSUFFICIENT_AVAILABLE':
        return 'The requested amount is higher than your available balance.';
      case 'FUNDRAISING_WITHDRAWAL_MAKER_CHECKER_REQUIRED':
        return 'This withdrawal needs a separate reviewer before it can be approved.';
      case 'FUNDRAISING_WITHDRAWAL_REASON_REQUIRED':
        return 'A decision reason is required for this withdrawal.';
      case 'FUNDRAISING_ACCOUNT_NOT_VERIFIED_FOR_WITHDRAWAL':
        return 'Complete verification or wait for review before requesting a withdrawal.';
      case 'CENTRAL_TOKEN_EXPIRED':
      case 'TOKEN_REVOKED':
        return 'Your session has expired. Please sign in again.';
      case 'FUNDRAISING_DATETIME_INVALID':
        return fundraisingValidationDetailMessage(error) ??
            'A date field is invalid. Please select it again.';
      case 'FUNDRAISING_VALIDATION_ERROR':
        return fundraisingValidationDetailMessage(error) ??
            'Please check the highlighted details and try again.';
    }
    if (error.isNetworkError) {
      return 'We could not reach the server. Please check your connection and try again.';
    }
    if ((error.statusCode ?? 0) >= 500) {
      return 'The service is temporarily unavailable. Please try again shortly.';
    }
    if ((error.statusCode ?? 0) == 400 || (error.statusCode ?? 0) == 422) {
      return 'Please check the highlighted details and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  return 'Something went wrong. Please try again.';
}
