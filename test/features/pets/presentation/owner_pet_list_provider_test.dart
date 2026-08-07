import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/pets/data/models/pet_model.dart';
import 'package:furtail_app/features/pets/presentation/providers/pet_providers.dart';
import 'package:furtail_app/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.onGet}) : super(dio: Dio());

  Future<dynamic> Function(String url)? onGet;

  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final handler = onGet;
    if (handler == null) {
      return {
        'success': true,
        'data': {'items': const []},
      };
    }
    return handler(url);
  }
}

void main() {
  test(
    'upserted pet survives an older empty refresh and remains after server refresh',
    () async {
      final firstResponse = Completer<dynamic>();
      final api = _FakeApiClient(onGet: (_) => firstResponse.future);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(ownerPetListProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      notifier.upsert(
        const PetModel(id: 42, name: 'Milo', animalTypeId: 1, breedId: 2),
      );

      firstResponse.complete({
        'success': true,
        'data': {'items': <Map<String, dynamic>>[]},
      });
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ownerPetListProvider).pets.single.id, 42);

      api.onGet = (_) async => {
        'success': true,
        'data': {
          'items': [
            {'id': 42, 'name': 'Milo', 'animalTypeId': 1, 'breedId': 2},
          ],
        },
      };

      await notifier.refresh();

      final state = container.read(ownerPetListProvider);
      expect(state.pets, hasLength(1));
      expect(state.pets.single.id, 42);
      expect(state.pets.single.name, 'Milo');
      expect(state.error, isNull);
    },
  );
}
