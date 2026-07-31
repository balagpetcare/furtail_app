import 'package:flutter/foundation.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_media_models.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';

class AdoptionMediaSession {
  AdoptionMediaSession._({
    required this.sessionId,
    required this.storageKey,
    required this.contentId,
  });

  final String sessionId;
  final String storageKey;
  final String contentId;

  factory AdoptionMediaSession.forListing({int? existingListingId}) {
    if (existingListingId != null) {
      final listingId = existingListingId.toString();
      return AdoptionMediaSession._(
        sessionId: 'listing:$listingId',
        storageKey: 'adoption:listing:$listingId',
        contentId: listingId,
      );
    }

    final sessionId = _newSessionId();
    return AdoptionMediaSession._(
      sessionId: 'create:$sessionId',
      storageKey: 'adoption:create:$sessionId',
      contentId: sessionId,
    );
  }

  String idempotencyKeyFor(String itemId) => '$sessionId:$itemId';

  static String _newSessionId() =>
      UniqueKey().toString().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
}

List<MediaDraftItem> adoptionMediaItemsFromServer(
  Iterable<AdoptionMediaUiModel> media,
) {
  final seen = <int>{};
  final out = <MediaDraftItem>[];

  for (final item in media) {
    final mediaId = item.id;
    if (mediaId == null || !seen.add(mediaId)) continue;
    out.add(
      MediaDraftItem(
        id: mediaId.toString(),
        type: item.isVideo ? MediaDraftType.video : MediaDraftType.image,
        fileName: item.displayUrl.split('/').last,
        originalSizeBytes: 0,
        remoteMediaId: mediaId,
        remoteUrl: item.url,
        remoteHlsUrl: item.hlsUrl,
        remoteThumbnailUrl: item.thumbnailUrl,
        remoteStatus: item.status,
        mimeType: item.mimeType,
        state: MediaDraftState.ready,
        progress: 1,
      ),
    );
  }

  return out;
}

List<int> sanitizeAdoptionMediaIds(
  Iterable<MediaDraftItem> items, {
  Iterable<int> allowedExistingMediaIds = const <int>[],
}) {
  final allowedExisting = allowedExistingMediaIds.toSet();
  final resolved = <int>[];
  final seen = <int>{};

  for (final item in items) {
    final mediaId = item.remoteMediaId;
    if (mediaId == null) continue;

    final isServerOnly = item.localPath == null;
    final isKnownExisting = !isServerOnly || allowedExisting.contains(mediaId);
    if (!isKnownExisting) continue;
    if (!seen.add(mediaId)) continue;
    resolved.add(mediaId);
  }

  return resolved;
}
