import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.body, {this.statusCode = 200});
  final dynamic body;
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

AdoptionRemoteDs _dsWith(dynamic body, {int statusCode = 200}) {
  final dio = Dio(
    BaseOptions(baseUrl: 'http://localhost', validateStatus: (_) => true),
  )..httpClientAdapter = _CannedAdapter(body, statusCode: statusCode);
  return AdoptionRemoteDs(ApiClient(dio: dio));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Bangladesh resolution by ISO alpha-2 code', () {
    test(
      'resolves Bangladesh by iso2 "BD", regardless of list order',
      () async {
        final ds = _dsWith({
          'success': true,
          'data': [
            {'id': 2, 'iso2': 'IN', 'name': 'India'},
            {'id': 1, 'iso2': 'BD', 'name': 'Bangladesh'},
            {'id': 3, 'iso2': 'US', 'name': 'United States'},
          ],
        });
        final country = await ds.fetchBangladeshCountry();
        expect(country.iso2, 'BD');
        expect(country.id, 1);
      },
    );

    test(
      'does not depend on exact display-name casing/spacing — iso2 is authoritative',
      () async {
        final ds = _dsWith({
          'success': true,
          'data': [
            {'id': 5, 'iso2': 'bd', 'name': 'Peoples Republic of Bangladesh'},
          ],
        });
        final country = await ds.fetchBangladeshCountry();
        expect(country.id, 5);
      },
    );

    test(
      'throws a catchable error (not a crash) when the country list cannot be loaded',
      () async {
        final ds = _dsWith({
          'success': false,
          'error': {'code': 'INTERNAL_ERROR', 'message': 'x'},
        }, statusCode: 500);
        await expectLater(ds.fetchBangladeshCountry(), throwsA(anything));
      },
    );

    test(
      'throws when Bangladesh is absent from an otherwise-valid country list',
      () async {
        final ds = _dsWith({
          'success': true,
          'data': [
            {'id': 2, 'iso2': 'IN', 'name': 'India'},
          ],
        });
        await expectLater(ds.fetchBangladeshCountry(), throwsA(anything));
      },
    );
  });
}
