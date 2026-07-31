import 'package:furtail_app/features/location/domain/location_selection_request_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stale location responses cannot overwrite the latest selection', () {
    final guard = LocationSelectionRequestGuard();

    final firstRequest = guard.begin();
    var selectedName = 'Dhaka North City Corporation';

    final secondRequest = guard.begin();
    if (guard.isCurrent(firstRequest)) {
      selectedName = 'Old corporation';
    }
    if (guard.isCurrent(secondRequest)) {
      selectedName = 'Dhaka South City Corporation';
    }

    expect(selectedName, 'Dhaka South City Corporation');
    expect(guard.isCurrent(firstRequest), isFalse);
    expect(guard.isCurrent(secondRequest), isTrue);
  });
}
