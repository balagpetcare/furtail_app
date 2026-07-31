import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_deadline_options.dart';

void main() {
  group('FundraisingDeadlineOptions', () {
    test('calculates the 7-day deadline at local end of day', () {
      final deadline = FundraisingDeadlineOptions.calculateDeadline(
        now: DateTime(2026, 7, 31, 10),
        durationDays: 7,
      );

      expect(deadline, DateTime(2026, 8, 7, 23, 59));
    });

    test('calculates the 15-day deadline at local end of day', () {
      final deadline = FundraisingDeadlineOptions.calculateDeadline(
        now: DateTime(2026, 7, 31, 10),
        durationDays: 15,
      );

      expect(deadline, DateTime(2026, 8, 15, 23, 59));
    });

    test('calculates the 30-day deadline at local end of day', () {
      final deadline = FundraisingDeadlineOptions.calculateDeadline(
        now: DateTime(2026, 7, 31, 10),
        durationDays: 30,
      );

      expect(deadline, DateTime(2026, 8, 30, 23, 59));
    });

    test('calculates the 90-day deadline at local end of day', () {
      final deadline = FundraisingDeadlineOptions.calculateDeadline(
        now: DateTime(2026, 7, 31, 10),
        durationDays: 90,
      );

      expect(deadline, DateTime(2026, 10, 29, 23, 59));
    });

    test('handles end-of-month rollover', () {
      final deadline = FundraisingDeadlineOptions.calculateDeadline(
        now: DateTime(2026, 1, 31, 22),
        durationDays: 30,
      );

      expect(deadline, DateTime(2026, 3, 2, 23, 59));
    });

    test('restores a selected duration from the local draft', () {
      final draft = FundraisingDraftRecovery.empty().copyWith(
        campaignDurationDays: 15,
        deadline: DateTime(2026, 8, 15, 23, 59),
      );
      final restored = FundraisingDraftRecovery.fromEncoded(draft.encode());

      expect(restored.campaignDurationDays, 15);
      expect(restored.deadline!.toLocal(), DateTime(2026, 8, 15, 23, 59));
    });

    test('keeps old absolute-deadline drafts compatible', () {
      final restored = FundraisingDraftRecovery.fromJson(<String, dynamic>{
        'deadline': '2026-12-31T23:59:00.000',
      });

      expect(restored.campaignDurationDays, isNull);
      expect(restored.deadline, DateTime(2026, 12, 31, 23, 59));
    });
  });
}
