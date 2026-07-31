import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/common/presentation/providers/dhaka_location_providers.dart';
import 'package:furtail_app/features/common/presentation/widgets/dhaka_city_dropdowns.dart';

void main() {
  testWidgets('shows an explicit empty state when no Dhaka data is available', (
    tester,
  ) async {
    final override = dhakaLocationsProvider.overrideWith((ref, lang) async {
      return DhakaLocationsResponse(corporations: const [], wardCount: 0);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [override],
        child: MaterialApp(
          home: Scaffold(
            body: DhakaCityDropdowns(
              lang: 'en',
              corpId: null,
              zoneId: null,
              wardId: null,
              onCorpChanged: (_) {},
              onZoneChanged: (_) {},
              onWardChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.text('No Dhaka city corporation data is available.'),
      findsOneWidget,
    );
  });
}
