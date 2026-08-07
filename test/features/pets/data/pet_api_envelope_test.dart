import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/pets/data/pet_api_envelope.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  group('PetApiEnvelope', () {
    test('parses collection responses from data.items', () {
      final items = PetApiEnvelope.collectionItems({
        'success': true,
        'data': {
          'items': [
            {'id': 1, 'name': 'Milo'},
          ],
          'nextCursor': null,
        },
      }, url: '/api/v1/user/pets');

      expect(items, [
        {'id': 1, 'name': 'Milo'},
      ]);
    });

    test('missing or null optional items become an empty list', () {
      expect(
        PetApiEnvelope.collectionItems({
          'success': true,
          'data': {'items': null},
        }, url: '/api/v1/user/pets'),
        isEmpty,
      );
      expect(
        PetApiEnvelope.collectionItems({
          'success': true,
          'data': <String, dynamic>{},
        }, url: '/api/v1/user/pets'),
        isEmpty,
      );
      expect(PetApiEnvelope.optionalList(null), isEmpty);
      expect(PetApiEnvelope.optionalList('not a list'), isEmpty);
    });

    test('parses resource responses from data.item', () {
      final item = PetApiEnvelope.resourceItem({
        'success': true,
        'data': {
          'item': {'id': 2, 'name': 'Luna'},
        },
      }, url: '/api/v1/user/pets/2');

      expect(item['id'], 2);
      expect(item['name'], 'Luna');
    });

    test('malformed required envelopes throw a typed API error', () {
      expect(
        () => PetApiEnvelope.resourceItem({
          'success': true,
          'data': {'item': null},
        }, url: '/api/v1/user/pets/2'),
        throwsA(
          isA<ApiClientException>().having(
            (e) => e.code,
            'code',
            'MALFORMED_RESPONSE',
          ),
        ),
      );
      expect(
        () => PetApiEnvelope.collectionItems({
          'success': true,
          'data': {'items': 'bad'},
        }, url: '/api/v1/user/pets'),
        throwsA(
          isA<ApiClientException>().having(
            (e) => e.code,
            'code',
            'MALFORMED_RESPONSE',
          ),
        ),
      );
    });
  });
}
