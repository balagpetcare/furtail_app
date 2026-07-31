import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_media_models.dart';
import 'package:furtail_app/features/adoption/presentation/utils/adoption_media_session.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';

void main() {
  test('new create sessions get unique storage and content ids', () {
    final first = AdoptionMediaSession.forListing();
    final second = AdoptionMediaSession.forListing();

    expect(first.storageKey, isNot(equals(second.storageKey)));
    expect(first.contentId, isNot(equals(second.contentId)));
    expect(
      first.idempotencyKeyFor('photo-1'),
      isNot(equals(second.idempotencyKeyFor('photo-1'))),
    );
  });

  test(
    'editing sessions bind to the listing id and keep stable idempotency keys',
    () {
      final session = AdoptionMediaSession.forListing(existingListingId: 42);

      expect(session.storageKey, 'adoption:listing:42');
      expect(session.contentId, '42');
      expect(session.idempotencyKeyFor('media-abc'), 'listing:42:media-abc');
    },
  );

  test('server media mapping deduplicates stable ids and preserves order', () {
    final media = adoptionMediaItemsFromServer(<AdoptionMediaUiModel>[
      const AdoptionMediaUiModel(
        id: 7,
        url: 'https://cdn.example.test/a.jpg',
        type: 'IMAGE',
      ),
      const AdoptionMediaUiModel(
        id: 7,
        url: 'https://cdn.example.test/dup.jpg',
        type: 'IMAGE',
      ),
      const AdoptionMediaUiModel(
        id: 8,
        url: 'https://cdn.example.test/b.jpg',
        type: 'IMAGE',
      ),
    ]);

    expect(media.map((item) => item.remoteMediaId), <int>[7, 8]);
    expect(media.first.fileName, 'a.jpg');
  });

  test('stale server-only ids are removed while valid new uploads remain', () {
    final items = <MediaDraftItem>[
      const MediaDraftItem(
        id: 'server-1',
        type: MediaDraftType.image,
        fileName: 'server-1.jpg',
        originalSizeBytes: 0,
        remoteMediaId: 7,
        state: MediaDraftState.ready,
      ),
      const MediaDraftItem(
        id: 'server-stale',
        type: MediaDraftType.image,
        fileName: 'server-stale.jpg',
        originalSizeBytes: 0,
        remoteMediaId: 99,
        state: MediaDraftState.ready,
      ),
      const MediaDraftItem(
        id: 'new-1',
        type: MediaDraftType.image,
        fileName: 'new-1.jpg',
        originalSizeBytes: 0,
        localPath: '/tmp/new-1.jpg',
        remoteMediaId: 1001,
        state: MediaDraftState.ready,
      ),
    ];

    final ids = sanitizeAdoptionMediaIds(
      items,
      allowedExistingMediaIds: <int>{7},
    );

    expect(ids, <int>[7, 1001]);
  });

  test('brand-new create sessions sanitize to zero inherited media', () {
    final ids = sanitizeAdoptionMediaIds(<MediaDraftItem>[
      const MediaDraftItem(
        id: 'stale-server',
        type: MediaDraftType.image,
        fileName: 'stale-server.jpg',
        originalSizeBytes: 0,
        remoteMediaId: 77,
        state: MediaDraftState.ready,
      ),
    ]);

    expect(ids, isEmpty);
  });
}
