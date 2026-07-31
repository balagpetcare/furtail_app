import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/common/presentation/providers/bd_location_providers.dart';
import 'package:furtail_app/features/location/presentation/widgets/location_selector_widget.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects a division from the picker', (tester) async {
    int? selectedDivisionId;
    String? selectedDivisionName;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bdDivisionsProvider.overrideWith(
            (ref) async => const [
              BdDivision(id: 1, code: 'DIV-1', nameEn: 'Dhaka'),
              BdDivision(id: 2, code: 'DIV-2', nameEn: 'Chattogram'),
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
              onDistrictChanged: null,
              onUpazilaChanged: null,
              onUnionChanged: null,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bd-location-division')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dhaka').last);
    await tester.pumpAndSettle();

    expect(selectedDivisionId, 1);
    expect(selectedDivisionName, 'Dhaka');
  });

  testWidgets(
    'selector tile text uses theme-derived color, not hardcoded black, in dark mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bdDivisionsProvider.overrideWith(
              (ref) async => const [
                BdDivision(id: 1, code: 'DIV-1', nameEn: 'Dhaka'),
              ],
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.dark(),
              useMaterial3: true,
            ),
            home: Scaffold(
              body: LocationSelectorWidget(
                divisionId: 1,
                districtId: null,
                upazilaId: null,
                unionId: null,
                divisionName: 'Dhaka',
                onDivisionChanged: (_, _) {},
                onDistrictChanged: null,
                onUpazilaChanged: null,
                onUnionChanged: null,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final label = find.text('Dhaka').first;
      final scheme = Theme.of(tester.element(label)).colorScheme;
      final text = tester.widget<Text>(label);

      // The selected value must render in a theme-derived color, never a
      // hardcoded dark color that would be unreadable against a dark
      // Material 3 surface.
      expect(text.style?.color, scheme.onSurface);
      expect(text.style?.color, isNot(Colors.black87));
    },
  );

  testWidgets('prefilled DNCC/DSCC selections infer the urban path', (
    tester,
  ) async {
    LocationAddressMode? selectedMode;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bdDivisionsProvider.overrideWith(
            (ref) async => const [
              BdDivision(id: 1, code: 'DIV-1', nameEn: 'Dhaka'),
            ],
          ),
          bdDistrictsProvider(1).overrideWith(
            (ref) async => const [
              BdDistrict(
                id: 10,
                code: 'DIS-10',
                nameEn: 'Dhaka District',
                divisionId: 1,
              ),
            ],
          ),
          bdCityCorporationsProvider(10).overrideWith(
            (ref) async => const [
              BdArea(
                id: 100,
                code: 'CC-DNCC',
                nameEn: 'Dhaka North City Corporation',
                type: 'CITY_CORPORATION',
                districtId: 10,
              ),
              BdArea(
                id: 101,
                code: 'CC-DSCC',
                nameEn: 'Dhaka South City Corporation',
                type: 'CITY_CORPORATION',
                districtId: 10,
              ),
            ],
          ),
          bdZonesProvider(100).overrideWith(
            (ref) async => const [
              BdArea(
                id: 200,
                code: 'ZONE-01',
                nameEn: 'Zone 1',
                type: 'ZONE',
                parentId: 100,
              ),
            ],
          ),
          bdWardsProvider(200).overrideWith(
            (ref) async => const [
              BdArea(
                id: 300,
                code: 'WARD-01',
                nameEn: 'Ward 1',
                type: 'WARD',
                parentId: 200,
              ),
            ],
          ),
          bdUpazilasProvider(10).overrideWith(
            (ref) async => const [
              BdUpazila(
                id: 400,
                code: 'UPZ-400',
                nameEn: 'Savar',
                districtId: 10,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LocationSelectorWidget(
              divisionId: 1,
              districtId: 10,
              addressMode: null,
              cityCorporationId: 100,
              zoneId: 200,
              wardId: 300,
              onAddressModeChanged: (mode) => selectedMode = mode,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(selectedMode, LocationAddressMode.urban);
    expect(
      find.byKey(const ValueKey('bd-location-city-corporation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bd-location-zone')), findsOneWidget);
    expect(find.byKey(const ValueKey('bd-location-ward')), findsOneWidget);
    expect(find.byKey(const ValueKey('bd-location-upazila')), findsNothing);
  });

  testWidgets('urban hierarchy stops at ward and shows location details', (
    tester,
  ) async {
    String? details;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bdDivisionsProvider.overrideWith(
            (ref) async => const [
              BdDivision(id: 1, code: 'DIV-1', nameEn: 'Dhaka'),
            ],
          ),
          bdDistrictsProvider(1).overrideWith(
            (ref) async => const [
              BdDistrict(
                id: 10,
                code: 'DIS-10',
                nameEn: 'Dhaka District',
                divisionId: 1,
              ),
            ],
          ),
          bdCityCorporationsProvider(10).overrideWith(
            (ref) async => const [
              BdArea(
                id: 100,
                code: 'CC-DNCC',
                nameEn: 'Dhaka North City Corporation',
                type: 'CITY_CORPORATION',
                districtId: 10,
              ),
              BdArea(
                id: 101,
                code: 'CC-DSCC',
                nameEn: 'Dhaka South City Corporation',
                type: 'CITY_CORPORATION',
                districtId: 10,
              ),
            ],
          ),
          bdZonesProvider(100).overrideWith(
            (ref) async => const [
              BdArea(
                id: 200,
                code: 'ZONE-01',
                nameEn: 'Zone 1',
                type: 'ZONE',
                parentId: 100,
              ),
            ],
          ),
          bdWardsProvider(200).overrideWith(
            (ref) async => const [
              BdArea(
                id: 300,
                code: 'WARD-01',
                nameEn: 'Ward 1',
                type: 'WARD',
                parentId: 200,
              ),
            ],
          ),
          bdUpazilasProvider(10).overrideWith(
            (ref) async => const [
              BdUpazila(
                id: 400,
                code: 'UPZ-400',
                nameEn: 'Tejgaon',
                districtId: 10,
              ),
            ],
          ),
          bdUnionsProvider(400).overrideWith(
            (ref) async => const [
              BdUnion(
                id: 500,
                code: 'UNI-500',
                nameEn: 'Tejgaon Union',
                upazilaId: 400,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _LocationSelectorHarness(
              onAreaChanged: (_, name) => details = name,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _selectChoice(
      tester,
      const ValueKey('bd-location-division'),
      'Dhaka',
    );
    await _selectChoice(
      tester,
      const ValueKey('bd-location-district'),
      'Dhaka District',
    );

    await _selectChoice(
      tester,
      const ValueKey('bd-location-address-type'),
      'City Corporation / Urban',
    );
    await tester.pumpAndSettle();

    await _selectChoice(
      tester,
      const ValueKey('bd-location-city-corporation'),
      'Dhaka North City Corporation',
    );
    await _selectChoice(tester, const ValueKey('bd-location-zone'), 'Zone 1');
    await _selectChoice(tester, const ValueKey('bd-location-ward'), 'Ward 1');

    expect(find.text('Location details'), findsOneWidget);
    expect(find.text('Area / Locality'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Location details'),
      'Apartment 4B',
    );
    await tester.pump();

    expect(details, 'Apartment 4B');
  });

  testWidgets('rural hierarchy stops at union and shows location details', (
    tester,
  ) async {
    String? details;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bdDivisionsProvider.overrideWith(
            (ref) async => const [
              BdDivision(id: 1, code: 'DIV-1', nameEn: 'Dhaka'),
            ],
          ),
          bdDistrictsProvider(1).overrideWith(
            (ref) async => const [
              BdDistrict(
                id: 10,
                code: 'DIS-10',
                nameEn: 'Dhaka',
                divisionId: 1,
              ),
            ],
          ),
          bdUpazilasProvider(10).overrideWith(
            (ref) async => const [
              BdUpazila(
                id: 400,
                code: 'UPZ-400',
                nameEn: 'Tejgaon',
                districtId: 10,
              ),
            ],
          ),
          bdUnionsProvider(400).overrideWith(
            (ref) async => const [
              BdUnion(
                id: 500,
                code: 'UNI-500',
                nameEn: 'Tejgaon Union',
                upazilaId: 400,
              ),
            ],
          ),
          bdCityCorporationsProvider(10).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _LocationSelectorHarness(
              onAreaChanged: (_, name) => details = name,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _selectChoice(
      tester,
      const ValueKey('bd-location-division'),
      'Dhaka',
    );
    await _selectChoice(
      tester,
      const ValueKey('bd-location-district'),
      'Dhaka',
    );
    await _selectChoice(
      tester,
      const ValueKey('bd-location-upazila'),
      'Tejgaon',
    );
    await _selectChoice(
      tester,
      const ValueKey('bd-location-union'),
      'Tejgaon Union',
    );

    expect(find.text('Location details'), findsOneWidget);
    expect(find.text('Area / Locality'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Location details'),
      'Behind the mosque',
    );
    await tester.pump();

    expect(details, 'Behind the mosque');
  });

  testWidgets('changing a parent clears dependent selections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bdDivisionsProvider.overrideWith(
            (ref) async => const [
              BdDivision(id: 1, code: 'DIV-1', nameEn: 'Dhaka'),
              BdDivision(id: 2, code: 'DIV-2', nameEn: 'Chattogram'),
            ],
          ),
          bdDistrictsProvider(1).overrideWith(
            (ref) async => const [
              BdDistrict(
                id: 10,
                code: 'DIS-10',
                nameEn: 'Dhaka District',
                divisionId: 1,
              ),
            ],
          ),
          bdDistrictsProvider(2).overrideWith(
            (ref) async => const [
              BdDistrict(
                id: 20,
                code: 'DIS-20',
                nameEn: 'Comilla District',
                divisionId: 2,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: _LocationSelectorHarness()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _selectChoice(
      tester,
      const ValueKey('bd-location-division'),
      'Dhaka',
    );
    await _selectChoice(
      tester,
      const ValueKey('bd-location-district'),
      'Dhaka District',
    );
    expect(find.text('Dhaka District'), findsOneWidget);

    await _selectChoice(
      tester,
      const ValueKey('bd-location-division'),
      'Chattogram',
    );
    await tester.pumpAndSettle();

    expect(find.text('Comilla District'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bd-location-district')),
        matching: find.text('Select'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a retry action when location catalogs fail to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bdDivisionsProvider.overrideWith((ref) async {
            throw ApiClientException(
              message: 'Connection refused',
              dioExceptionType: 'connectionError',
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LocationSelectorWidget(
              divisionId: null,
              districtId: null,
              upazilaId: null,
              unionId: null,
              onDivisionChanged: null,
              onDistrictChanged: null,
              onUpazilaChanged: null,
              onUnionChanged: null,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('Some location data failed to load'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });
}

class _LocationSelectorHarness extends StatefulWidget {
  const _LocationSelectorHarness({this.onAreaChanged});

  final LocationChanged? onAreaChanged;

  @override
  State<_LocationSelectorHarness> createState() =>
      _LocationSelectorHarnessState();
}

class _LocationSelectorHarnessState extends State<_LocationSelectorHarness> {
  int? _divisionId;
  int? _districtId;
  LocationAddressMode? _addressMode;
  int? _cityCorporationId;
  int? _zoneId;
  int? _wardId;
  int? _upazilaId;
  int? _unionId;
  String? _cityCorporationName;
  String? _zoneName;
  String? _wardName;
  String? _upazilaName;
  String? _unionName;

  @override
  Widget build(BuildContext context) {
    return LocationSelectorWidget(
      divisionId: _divisionId,
      districtId: _districtId,
      addressMode: _addressMode,
      cityCorporationId: _cityCorporationId,
      cityCorporationName: _cityCorporationName,
      zoneId: _zoneId,
      zoneName: _zoneName,
      wardId: _wardId,
      wardName: _wardName,
      upazilaId: _upazilaId,
      upazilaName: _upazilaName,
      unionId: _unionId,
      unionName: _unionName,
      onDivisionChanged: (id, name) {
        setState(() {
          _divisionId = id;
          _districtId = null;
          _addressMode = null;
          _cityCorporationId = null;
          _cityCorporationName = null;
          _zoneId = null;
          _zoneName = null;
          _wardId = null;
          _wardName = null;
          _upazilaId = null;
          _upazilaName = null;
          _unionId = null;
          _unionName = null;
        });
      },
      onDistrictChanged: (id, name) {
        setState(() {
          _districtId = id;
          _addressMode = null;
          _cityCorporationId = null;
          _cityCorporationName = null;
          _zoneId = null;
          _zoneName = null;
          _wardId = null;
          _wardName = null;
          _upazilaId = null;
          _upazilaName = null;
          _unionId = null;
          _unionName = null;
        });
      },
      onAddressModeChanged: (mode) {
        setState(() {
          _addressMode = mode;
          _cityCorporationId = null;
          _cityCorporationName = null;
          _zoneId = null;
          _zoneName = null;
          _wardId = null;
          _wardName = null;
          _upazilaId = null;
          _upazilaName = null;
          _unionId = null;
          _unionName = null;
        });
      },
      onCityCorporationChanged: (id, name) {
        setState(() {
          _addressMode = LocationAddressMode.urban;
          _cityCorporationId = id;
          _cityCorporationName = name;
          _zoneId = null;
          _zoneName = null;
          _wardId = null;
          _wardName = null;
          _upazilaId = null;
          _upazilaName = null;
          _unionId = null;
          _unionName = null;
        });
      },
      onZoneChanged: (id, name) {
        setState(() {
          _addressMode = LocationAddressMode.urban;
          _zoneId = id;
          _zoneName = name;
          _wardId = null;
          _wardName = null;
        });
      },
      onWardChanged: (id, name) {
        setState(() {
          _addressMode = LocationAddressMode.urban;
          _wardId = id;
          _wardName = name;
        });
      },
      onUpazilaChanged: (id, name) {
        setState(() {
          _addressMode = LocationAddressMode.rural;
          _upazilaId = id;
          _upazilaName = name;
          _cityCorporationId = null;
          _cityCorporationName = null;
          _zoneId = null;
          _zoneName = null;
          _wardId = null;
          _wardName = null;
          _unionId = null;
          _unionName = null;
        });
      },
      onUnionChanged: (id, name) {
        setState(() {
          _addressMode = LocationAddressMode.rural;
          _unionId = id;
          _unionName = name;
          _cityCorporationId = null;
          _cityCorporationName = null;
          _zoneId = null;
          _zoneName = null;
          _wardId = null;
          _wardName = null;
        });
      },
      onAreaChanged: widget.onAreaChanged,
    );
  }
}

Future<void> _selectChoice(
  WidgetTester tester,
  ValueKey<String> selectorKey,
  String label,
) async {
  await tester.tap(find.byKey(selectorKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
