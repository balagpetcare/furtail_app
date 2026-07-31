import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furtail_app/features/common/data/services/reference_data_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Map<String, dynamic> toJson(List<int> list) => {'items': list};
  List<int> fromJson(Map<String, dynamic> json) =>
      (json['items'] as List).cast<int>();

  group('ReferenceDataCache', () {
    test(
      'fetches from network on first call, then serves from cache without calling fetch again',
      () async {
        final cache = ReferenceDataCache();
        var fetchCount = 0;
        Future<List<int>> fetch() async {
          fetchCount++;
          return [1, 2, 3];
        }

        final first = await cache.getOrFetch(
          key: 'k',
          fetch: fetch,
          toJson: toJson,
          fromJson: fromJson,
        );
        final second = await cache.getOrFetch(
          key: 'k',
          fetch: fetch,
          toJson: toJson,
          fromJson: fromJson,
        );

        expect(first, [1, 2, 3]);
        expect(second, [1, 2, 3]);
        expect(fetchCount, 1);
      },
    );

    test(
      'forceRefresh always hits the network and is never treated as authoritative-forever',
      () async {
        final cache = ReferenceDataCache();
        var fetchCount = 0;
        Future<List<int>> fetch() async {
          fetchCount++;
          return [fetchCount];
        }

        await cache.getOrFetch(
          key: 'k',
          fetch: fetch,
          toJson: toJson,
          fromJson: fromJson,
        );
        final refreshed = await cache.getOrFetch(
          key: 'k',
          fetch: fetch,
          toJson: toJson,
          fromJson: fromJson,
          forceRefresh: true,
        );

        expect(fetchCount, 2);
        expect(refreshed, [2]);
      },
    );

    test(
      'falls back to the cached value when a subsequent network fetch fails',
      () async {
        final cache = ReferenceDataCache();
        var shouldFail = false;
        Future<List<int>> fetch() async {
          if (shouldFail) throw Exception('network down');
          return [9, 9, 9];
        }

        final first = await cache.getOrFetch(
          key: 'k',
          fetch: fetch,
          toJson: toJson,
          fromJson: fromJson,
        );
        shouldFail = true;
        final fallback = await cache.getOrFetch(
          key: 'k',
          fetch: fetch,
          toJson: toJson,
          fromJson: fromJson,
          forceRefresh: true,
        );

        expect(first, [9, 9, 9]);
        expect(fallback, [
          9,
          9,
          9,
        ]); // stale cache used instead of surfacing the error
      },
    );

    test(
      'rethrows when the network fails and there is no cached fallback at all',
      () async {
        final cache = ReferenceDataCache();
        Future<List<int>> fetch() async => throw Exception('boom');

        expect(
          () => cache.getOrFetch(
            key: 'k',
            fetch: fetch,
            toJson: toJson,
            fromJson: fromJson,
          ),
          throwsException,
        );
      },
    );

    test(
      'invalidate() forces the next read to hit the network again',
      () async {
        final cache = ReferenceDataCache();
        var fetchCount = 0;
        Future<List<int>> fetch() async {
          fetchCount++;
          return [fetchCount];
        }

        await cache.getOrFetch(
          key: 'k',
          fetch: fetch,
          toJson: toJson,
          fromJson: fromJson,
        );
        await cache.invalidate('k');
        await cache.getOrFetch(
          key: 'k',
          fetch: fetch,
          toJson: toJson,
          fromJson: fromJson,
        );

        expect(fetchCount, 2);
      },
    );

    test('a stale (TTL-expired) cache entry triggers a fresh fetch', () async {
      final cache = ReferenceDataCache(ttl: const Duration(milliseconds: 1));
      var fetchCount = 0;
      Future<List<int>> fetch() async {
        fetchCount++;
        return [fetchCount];
      }

      await cache.getOrFetch(
        key: 'k',
        fetch: fetch,
        toJson: toJson,
        fromJson: fromJson,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      final result = await cache.getOrFetch(
        key: 'k',
        fetch: fetch,
        toJson: toJson,
        fromJson: fromJson,
      );

      expect(fetchCount, 2);
      expect(result, [2]);
    });
  });
}
