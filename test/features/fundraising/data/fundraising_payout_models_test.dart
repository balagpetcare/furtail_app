import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_payout_models.dart';

void main() {
  test(
    'withdrawal models accept numeric API fields as JSON numbers or decimal strings',
    () {
      final fromNumbers = FundraisingWithdrawBalanceSummary.fromJson({
        'totalRaisedMinor': 100,
        'pendingMinor': 20,
        'availableMinor': 80,
        'reservedMinor': 5,
        'transferredMinor': 15,
      });
      final fromStrings = FundraisingWithdrawBalanceSummary.fromJson({
        'totalRaisedMinor': '100',
        'pendingMinor': '20',
        'availableMinor': '80',
        'reservedMinor': '5',
        'transferredMinor': '15',
      });

      expect(fromStrings.totalRaisedMinor, fromNumbers.totalRaisedMinor);
      expect(fromStrings.availableMinor, fromNumbers.availableMinor);
      expect(
        FundraisingWithdrawRequest.fromJson({
          'id': '7',
          'campaignId': '9',
          'amount': '12345',
          'status': 'SUBMITTED',
          'createdAt': '2026-07-25T00:00:00.000Z',
        }).amount,
        12345,
      );
    },
  );
}
