import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/common/data/repositories/animal_taxonomy_repository.dart';
import 'package:furtail_app/features/common/data/repositories/bd_locations_repository.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Routes requests by exact path+query to canned envelope responses,
/// mirroring the real `{success, data: {items, ...}, meta}` shape the API
/// returns — this is what exposed the original "res['items'] always empty"
/// bug (the repository was reading `items` off the raw envelope instead of
/// `envelope['data']['items']`).
class _RoutedAdapter implements HttpClientAdapter {
  _RoutedAdapter(this.routes);
  final Map<String, Map<String, dynamic>> routes;
  int callCount = 0;
  List<String> requestedPaths = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    final key =
        '${options.uri.path}${options.uri.query.isEmpty ? '' : '?${options.uri.query}'}';
    requestedPaths.add(key);
    final body = routes[key];
    if (body == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'success': false,
          'error': {'code': 'NOT_FOUND', 'message': 'no route'},
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> envelope(dynamic data) => {
  'success': true,
  'data': data,
  'meta': {
    'requestId': 'r1',
    'correlationId': 'c1',
    'timestamp': '2026-01-01T00:00:00Z',
  },
};

ApiClient _clientWithRoutes(
  Map<String, Map<String, dynamic>> routes, {
  _RoutedAdapter? capture,
}) {
  final adapter = capture ?? _RoutedAdapter(routes);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = adapter;
  return ApiClient(dio: dio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group(
    'AnimalTaxonomyRepository — successful loading and species scoping',
    () {
      test('loads active species from the envelope-wrapped response', () async {
        final client = _clientWithRoutes({
          '/api/v1/common/animal-types': envelope({
            'items': [
              {
                'id': 1,
                'code': 'DOG',
                'name': 'Dog',
                'nameBn': 'কুকুর',
                'displayOrder': 1,
              },
              {'id': 2, 'code': 'CAT', 'name': 'Cat', 'displayOrder': 2},
            ],
            'total': 2,
            'page': 1,
            'pageSize': 100,
          }),
        });
        final repo = AnimalTaxonomyRepository(client);
        final types = await repo.getAnimalTypes();
        expect(types.map((t) => t.code), ['DOG', 'CAT']);
      });

      test('loads breeds scoped to the requested species only', () async {
        final client = _clientWithRoutes({
          '/api/v1/common/breeds/1': envelope({
            'items': [
              {'id': 10, 'name': 'Labrador', 'animalTypeId': 1},
              {'id': 11, 'name': 'German Shepherd', 'animalTypeId': 1},
            ],
            'total': 2,
            'page': 1,
            'pageSize': 100,
          }),
        });
        final repo = AnimalTaxonomyRepository(client);
        final breeds = await repo.getBreeds(animalTypeId: 1);
        expect(breeds.every((b) => b.animalTypeId == 1), isTrue);
        expect(breeds.map((b) => b.name), ['Labrador', 'German Shepherd']);
      });
    },
  );

  group('BdLocationsRepository — the envelope-unwrap fix', () {
    test(
      'getDivisions correctly unwraps data.items (previously always returned empty)',
      () async {
        final client = _clientWithRoutes({
          '/api/v1/common/bd/divisions': envelope({
            'items': [
              {'id': 1, 'code': 'DIV-1', 'nameEn': 'Dhaka'},
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
          }),
        });
        final repo = BdLocationsRepository(client);
        final divisions = await repo.getDivisions();
        expect(divisions, hasLength(1));
        expect(divisions.first.nameEn, 'Dhaka');
      },
    );

    test(
      'cascading load: division -> districts -> upazilas resolve independently per parent',
      () async {
        final client = _clientWithRoutes({
          '/api/v1/common/bd/divisions': envelope({
            'items': [
              {'id': 1, 'code': 'DIV-1', 'nameEn': 'Dhaka'},
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
          }),
          '/api/v1/common/bd/districts?divisionId=1': envelope({
            'items': [
              {
                'id': 10,
                'code': 'DIS-10',
                'nameEn': 'Dhaka District',
                'divisionId': 1,
              },
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
          }),
          '/api/v1/common/bd/upazilas?districtId=10': envelope({
            'items': [
              {
                'id': 100,
                'code': 'UPA-100',
                'nameEn': 'Savar',
                'districtId': 10,
              },
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
          }),
        });
        final repo = BdLocationsRepository(client);
        final divisions = await repo.getDivisions();
        final districts = await repo.getDistricts(
          divisionId: divisions.first.id,
        );
        final upazilas = await repo.getUpazilas(districtId: districts.first.id);

        expect(divisions.single.nameEn, 'Dhaka');
        expect(districts.single.divisionId, divisions.single.id);
        expect(upazilas.single.districtId, districts.single.id);
      },
    );

    test(
      'urban path: city corporations -> zones -> ward/areas, never requiring a union/upazila',
      () async {
        final client = _clientWithRoutes({
          '/api/v1/common/bd/city-corporations?districtId=10': envelope({
            'items': [
              {
                'id': 500,
                'code': 'CC-DNCC',
                'nameEn': 'Dhaka North City Corporation',
                'type': 'CITY_CORPORATION',
                'districtId': 10,
              },
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
          }),
          '/api/v1/common/bd/zones?cityCorporationId=500': envelope({
            'items': [
              {
                'id': 501,
                'code': 'ZONE-1',
                'nameEn': 'Zone 1',
                'type': 'ZONE',
                'parentId': 500,
              },
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
          }),
          '/api/v1/common/bd/cc-areas?zoneId=501': envelope({
            'items': [
              {
                'id': 502,
                'code': 'WARD-1',
                'nameEn': 'Ward 1',
                'type': 'WARD',
                'parentId': 501,
              },
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
          }),
        });
        final repo = BdLocationsRepository(client);
        final cc = await repo.getCityCorporations(districtId: 10);
        final zones = await repo.getZones(cityCorporationId: cc.single.id);
        final wards = await repo.getCcAreas(zoneId: zones.single.id);

        expect(cc.single.unionId, isNull);
        expect(cc.single.upazilaId, isNull);
        expect(wards.single.nameEn, 'Ward 1');
      },
    );

    test('rural path: upazila -> union -> area', () async {
      final client = _clientWithRoutes({
        '/api/v1/location-master/unions?upazilaId=100&locale=en&pageSize=64':
            envelope({
              'items': [
                {
                  'id': 900,
                  'code': 'UNI-900',
                  'nameEn': 'Aminbazar',
                  'upazilaId': 100,
                },
              ],
              'total': 1,
              'page': 1,
              'pageSize': 100,
            }),
        '/api/v1/common/bd/areas?unionId=900': envelope({
          'items': [
            {
              'id': 901,
              'code': 'AREA-901',
              'nameEn': 'Aminbazar Bazar',
              'type': 'AREA',
              'unionId': 900,
            },
          ],
          'total': 1,
          'page': 1,
          'pageSize': 100,
        }),
      });
      final repo = BdLocationsRepository(client);
      final unions = await repo.getUnions(upazilaId: 100);
      final areas = await repo.getAreas(unionId: unions.single.id);

      expect(unions.single.nameEn, 'Aminbazar');
      expect(areas.single.unionId, unions.single.id);
    });

    test(
      'API failure surfaces as an exception the caller can retry on',
      () async {
        final client = _clientWithRoutes(
          {},
        ); // no routes registered -> 404 for everything
        final repo = BdLocationsRepository(client);
        await expectLater(repo.getDivisions(), throwsA(anything));
      },
    );
  });
}
