import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/location/presentation/providers/location_provider.dart';
import 'package:furtail_app/features/location/presentation/widgets/location_selector_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LocationSelectorWidget selects division from bottom sheet', (
    tester,
  ) async {
    int? selectedDivisionId;
    String? selectedDivisionName;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationDivisionsProvider.overrideWith(
            (ref) async => const [
              BdDivision(id: 1, code: 'DIV-1', nameEn: 'Dhaka'),
              BdDivision(id: 2, code: 'DIV-2', nameEn: 'Chattogram'),
            ],
          ),
          locationDistrictsProvider(1).overrideWith(
            (ref) async => const [
              BdDistrict(
                id: 10,
                code: 'DIS-10',
                nameEn: 'Dhaka',
                divisionId: 1,
              ),
            ],
          ),
          locationUpazilasProvider(10).overrideWith(
            (ref) async => const [
              BdUpazila(
                id: 100,
                code: 'UPZ-100',
                nameEn: 'Tejgaon',
                districtId: 10,
              ),
            ],
          ),
          locationUnionsProvider(100).overrideWith(
            (ref) async => const [
              BdUnion(
                id: 1000,
                code: 'UNI-1000',
                nameEn: 'Tejgaon Union',
                upazilaId: 100,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LocationSelectorWidget(
              divisionId: null,
              districtId: null,
              upazilaId: null,
              unionId: null,
              onDivisionChanged: (id, name) {
                selectedDivisionId = id;
                selectedDivisionName = name;
              },
              onDistrictChanged: (_, __) {},
              onUpazilaChanged: (_, __) {},
              onUnionChanged: (_, __) {},
              required: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open division picker.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Pick item from bottom sheet.
    await tester.tap(find.text('Dhaka').first);
    await tester.pumpAndSettle();

    expect(selectedDivisionId, 1);
    expect(selectedDivisionName, 'Dhaka');
  });
}

