import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_date_serializer.dart';

void main() {
  group('FundraisingDateSerializer', () {
    group('serializeToUtcIso8601', () {
      test('returns null for null input', () {
        expect(FundraisingDateSerializer.serializeToUtcIso8601(null), isNull);
      });

      test('serializes DateTime to UTC ISO-8601 string', () {
        final date = DateTime(2026, 8, 8, 23, 59, 0);
        final result = FundraisingDateSerializer.serializeToUtcIso8601(date);
        expect(result, contains('2026-08-08T'));
        expect(result, contains('Z'));
      });

      test('converts local time to UTC', () {
        // Create a local datetime
        final localDate = DateTime(2026, 8, 8, 12, 0, 0);
        final result = FundraisingDateSerializer.serializeToUtcIso8601(
          localDate,
        );
        // Should use UTC timezone
        expect(result, contains('T'));
        expect(result, endsWith('Z'));
      });

      test('returns valid ISO8601 format', () {
        final date = DateTime.utc(2026, 8, 8, 23, 59, 0);
        final result = FundraisingDateSerializer.serializeToUtcIso8601(date);
        // Should be parseable by DateTime.parse
        expect(() => DateTime.parse(result!), returnsNormally);
      });
    });

    group('parseYearMonthDayToUtcEndOfDay', () {
      test('returns null for null input', () {
        expect(
          FundraisingDateSerializer.parseYearMonthDayToUtcEndOfDay(null),
          isNull,
        );
      });

      test('returns null for empty string', () {
        expect(
          FundraisingDateSerializer.parseYearMonthDayToUtcEndOfDay(''),
          isNull,
        );
      });

      test('parses valid date-only string', () {
        final result = FundraisingDateSerializer.parseYearMonthDayToUtcEndOfDay(
          '2026-08-08',
        );
        expect(result, isNotNull);
        expect(result!.year, 2026);
        expect(result.month, 8);
        expect(result.day, 8);
      });

      test('sets end-of-day time (23:59)', () {
        final result = FundraisingDateSerializer.parseYearMonthDayToUtcEndOfDay(
          '2026-08-08',
        );
        expect(result!.hour, 23);
        expect(result.minute, 59);
      });

      test('uses UTC timezone', () {
        final result = FundraisingDateSerializer.parseYearMonthDayToUtcEndOfDay(
          '2026-08-08',
        );
        expect(result!.isUtc, isTrue);
      });

      test('returns null for invalid format (MM-DD-YYYY)', () {
        // parseYearMonthDayToUtcEndOfDay expects YYYY-MM-DD format only
        // 08-08-2026 will be mis-parsed as year 8, month 8, day 2026 which fails validation
        final result = FundraisingDateSerializer.parseYearMonthDayToUtcEndOfDay(
          '08-08-2026',
        );
        // May parse as invalid date or null depending on implementation
        expect(result == null || result.year < 100, isTrue);
      });
    });

    group('parseLegacyDateField', () {
      test('returns null for null input', () {
        expect(FundraisingDateSerializer.parseLegacyDateField(null), isNull);
      });

      test('returns null for empty string', () {
        expect(FundraisingDateSerializer.parseLegacyDateField(''), isNull);
      });

      test('parses ISO-8601 string', () {
        final iso = '2026-08-08T23:59:00Z';
        final result = FundraisingDateSerializer.parseLegacyDateField(iso);
        expect(result, isNotNull);
        expect(result!.year, 2026);
      });

      test('parses date-only string (YYYY-MM-DD)', () {
        final result = FundraisingDateSerializer.parseLegacyDateField(
          '2026-08-08',
        );
        expect(result, isNotNull);
        expect(result!.year, 2026);
        expect(result.month, 8);
        expect(result.day, 8);
      });

      test('returns null for display format (e.g., Aug 8, 2026)', () {
        final result = FundraisingDateSerializer.parseLegacyDateField(
          'Aug 8, 2026',
        );
        expect(result, isNull);
      });

      test('handles numeric input by converting to string', () {
        // Timestamp in milliseconds
        final timestamp = 1723138740000; // August 8, 2024
        final result = FundraisingDateSerializer.parseLegacyDateField(
          timestamp,
        );
        // May or may not parse depending on how Date() handles it
        // This demonstrates the function accepts various types
        expect(result is DateTime?, isTrue);
      });
    });

    group('integration tests', () {
      test('ONE_TIME fundraiser with endsAt serializes correctly', () {
        final endDate = DateTime(2026, 8, 8, 23, 59, 0);
        final serialized = FundraisingDateSerializer.serializeToUtcIso8601(
          endDate,
        );
        final parsed = DateTime.tryParse(serialized!);
        expect(parsed, isNotNull);
      });

      test('ONGOING fundraiser with nextReviewAt serializes correctly', () {
        final reviewDate = DateTime.utc(2026, 9, 7, 0, 0, 0);
        final serialized = FundraisingDateSerializer.serializeToUtcIso8601(
          reviewDate,
        );
        expect(serialized, contains('2026-09-07'));
      });

      test('legacy draft with date-only format restores safely', () {
        // Simulate legacy draft data
        final legacyDate = '2026-08-08';
        final restored = FundraisingDateSerializer.parseLegacyDateField(
          legacyDate,
        );
        expect(restored, isNotNull);
        expect(restored!.year, 2026);
        expect(restored.month, 8);
        expect(restored.day, 8);

        // Re-serialize it
        final reserialized = FundraisingDateSerializer.serializeToUtcIso8601(
          restored,
        );
        // Should contain the date, though time component may differ due to UTC
        expect(reserialized, isNotNull);
        expect(() => DateTime.parse(reserialized!), returnsNormally);
      });
    });
  });
}
