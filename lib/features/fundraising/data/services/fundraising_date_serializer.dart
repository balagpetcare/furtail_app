import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

class FundraisingDateSerializer {
  /// Serializes a DateTime to a valid UTC ISO-8601 string for API submission.
  ///
  /// - If [date] is null, returns null (for optional fields)
  /// - Always uses UTC timezone to ensure consistency
  /// - Returns format: "2026-08-08T23:59:00.000Z"
  static String? serializeToUtcIso8601(DateTime? date) {
    if (date == null) return null;
    return date.toUtc().toIso8601String();
  }

  /// Parses a date-only string (YYYY-MM-DD) into a DateTime at end-of-day UTC.
  /// Used for legacy draft recovery where only the date (not time) was stored.
  ///
  /// Returns null if [dateString] is null, empty, or invalid.
  static DateTime? parseYearMonthDayToUtcEndOfDay(String? dateString) {
    if (dateString == null || dateString.trim().isEmpty) return null;

    try {
      final parts = dateString.trim().split('-');
      if (parts.length != 3) return null;

      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);

      if (year == null || month == null || day == null) return null;

      // Create in UTC at end-of-day (23:59:00)
      return DateTime.utc(year, month, day, 23, 59, 0);
    } catch (e) {
      return null;
    }
  }

  /// Safely parses a DateTime from an ISO-8601 string or date-only string.
  /// Used for legacy draft recovery.
  ///
  /// Returns null if parsing fails.
  static DateTime? parseLegacyDateField(dynamic rawValue) {
    if (rawValue == null) return null;

    final value = rawValue.toString().trim();
    if (value.isEmpty) return null;

    // Try ISO-8601 first
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    // Try date-only format (YYYY-MM-DD)
    return parseYearMonthDayToUtcEndOfDay(value);
  }

  /// Logs sanitized date field serialization for debugging.
  /// Never logs personal data, coordinates, or full payloads.
  static void logSerializedDateFields(Map<String, dynamic> payload) {
    if (!kDebugMode) return;

    final dateFields = <String, String?>{};

    for (final entry in payload.entries) {
      final key = entry.key;
      final value = entry.value;

      // Track only known date fields
      if (key == 'startsAt' ||
          key == 'endsAt' ||
          key == 'deadline' ||
          key == 'nextReviewAt' ||
          key == 'securityLocationCapturedAt') {
        if (value == null) {
          dateFields[key] = 'null';
        } else if (value is String) {
          // Log only whether it looks like valid ISO8601
          final isValidIso = _isValidIso8601(value);
          dateFields[key] = isValidIso ? 'valid-iso8601' : 'invalid-format';
        } else {
          dateFields[key] = 'unexpected-type:${value.runtimeType}';
        }
      }
    }

    if (dateFields.isNotEmpty) {
      developer.log(
        'Fundraising date serialization: ${dateFields.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
        name: 'FundraisingDateSerializer',
      );
    }
  }

  static bool _isValidIso8601(String value) {
    return DateTime.tryParse(value) != null;
  }
}
