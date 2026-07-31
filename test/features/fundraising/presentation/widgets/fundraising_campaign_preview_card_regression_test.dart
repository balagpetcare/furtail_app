import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_campaign_preview_card.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<MediaDraftItem> mediaItems,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: FundraisingCampaignPreviewCard(
            draft: FundraisingDraftRecovery(
              title: 'Help Tuni recover',
              story: 'This is a long enough story to render the preview card.',
              category: 'TREATMENT',
              beneficiaryName: 'Tuni',
              beneficiaryType: 'PET',
              fundingMode: 'ONE_TIME',
              targetAmountMinor: 120000,
              endsAt: DateTime(2026, 9, 1),
              locationText: 'Dhaka, Bangladesh',
              expenses: const <FundraisingExpenseItem>[],
            ),
            mediaItems: mediaItems,
          ),
        ),
      ),
    ),
  );
  // Network images never resolve in a widget test, so settle a few frames
  // instead of pumpAndSettle (which would time out on the retry timers).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  test(
    'two ready images stay visible and a relative media URL is normalized',
    () {
      final items = <MediaDraftItem>[
        MediaDraftItem(
          id: 'image-1',
          type: MediaDraftType.image,
          fileName: 'first.jpg',
          originalSizeBytes: 1234,
          remoteMediaId: 11,
          remoteUrl: '/api/v1/media/11/first.jpg',
          state: MediaDraftState.ready,
        ),
        MediaDraftItem(
          id: 'image-2',
          type: MediaDraftType.image,
          fileName: 'second.jpg',
          originalSizeBytes: 2345,
          remoteMediaId: 12,
          remoteUrl: 'https://cdn.example.com/media/12/second.jpg',
          state: MediaDraftState.ready,
        ),
      ];

      final visible = fundraisingPreviewVisibleMediaItems(items);

      expect(visible, hasLength(2));
      expect(
        fundraisingMediaPreviewNetworkUrl(items.first),
        MediaUrl.normalize('/api/v1/media/11/first.jpg'),
      );
      expect(
        fundraisingMediaPreviewNetworkUrl(items.last),
        MediaUrl.normalize('https://cdn.example.com/media/12/second.jpg'),
      );
    },
  );

  test('a READY video with no thumbnail source is not counted as a usable '
      'preview (previously inflated "Evidence" past what could render)', () {
    final readyButThumbnailless = MediaDraftItem(
      id: 'video-no-thumb',
      type: MediaDraftType.video,
      fileName: 'clip.mp4',
      originalSizeBytes: 5678,
      remoteMediaId: 22,
      remoteUrl: '/api/v1/media/22/clip.mp4',
      // No thumbnailPath, no remoteThumbnailUrl — nothing this card can
      // actually paint, even though the item is fully uploaded (READY).
      state: MediaDraftState.ready,
    );

    expect(
      fundraisingPreviewVisibleMediaItems(<MediaDraftItem>[
        readyButThumbnailless,
      ]),
      isEmpty,
    );
  });

  group('rendered widget tree', () {
    testWidgets(
      'two READY items (one image, one video) build a non-zero-height '
      'media strip with a visible preview for each',
      (tester) async {
        final items = <MediaDraftItem>[
          MediaDraftItem(
            id: 'image-1',
            type: MediaDraftType.image,
            fileName: 'first.jpg',
            originalSizeBytes: 1234,
            remoteMediaId: 11,
            remoteUrl: '/api/v1/media/11/first.jpg',
            state: MediaDraftState.ready,
          ),
          MediaDraftItem(
            id: 'video-1',
            type: MediaDraftType.video,
            fileName: 'clip.mp4',
            originalSizeBytes: 5678,
            remoteMediaId: 22,
            remoteUrl: '/api/v1/media/22/clip.mp4',
            remoteThumbnailUrl: '/api/v1/media/22/clip-thumb.jpg',
            state: MediaDraftState.ready,
          ),
        ];

        await _pumpCard(tester, mediaItems: items);

        // "Evidence 2" must only ever reflect items that actually have a
        // usable preview source (see `fundraisingPreviewVisibleMediaItems`).
        expect(find.text('2'), findsOneWidget);

        // The hero + horizontal strip must actually be laid out — a
        // zero-height/empty branch here is what silently drops both
        // previews even though the "Evidence 2" count looks correct.
        final heroBox = tester.renderObject<RenderBox>(
          find.byType(SizedBox).first,
        );
        expect(heroBox.size.height, greaterThan(0));

        // The image item renders through the network image resolver.
        expect(find.byType(CachedNetworkImage), findsWidgets);
        // The video item's thumbnail also resolves through the same
        // network image resolver, with the play-button overlay on top —
        // not the bare placeholder icon in place of a real thumbnail.
        expect(find.byIcon(Icons.play_circle_fill_rounded), findsWidgets);
      },
    );

    testWidgets('a failed item never suppresses a successful item\'s preview', (
      tester,
    ) async {
      final items = <MediaDraftItem>[
        MediaDraftItem(
          id: 'image-ok',
          type: MediaDraftType.image,
          fileName: 'ok.jpg',
          originalSizeBytes: 1234,
          remoteMediaId: 11,
          remoteUrl: '/api/v1/media/11/ok.jpg',
          state: MediaDraftState.ready,
        ),
        MediaDraftItem(
          id: 'image-failed',
          type: MediaDraftType.image,
          fileName: 'failed.jpg',
          originalSizeBytes: 999,
          state: MediaDraftState.failed,
        ),
      ];

      await _pumpCard(tester, mediaItems: items);

      expect(find.text('1'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsWidgets);
    });

    testWidgets('a local (not-yet-uploaded) image renders via Image.file', (
      tester,
    ) async {
      final tempFile = File(
        '${Directory.systemTemp.path}/fundraising_preview_test.jpg',
      );
      tempFile.writeAsBytesSync(<int>[0]);
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      final items = <MediaDraftItem>[
        MediaDraftItem(
          id: 'local-1',
          type: MediaDraftType.image,
          fileName: 'local.jpg',
          originalSizeBytes: 1,
          localPath: tempFile.path,
          state: MediaDraftState.local,
        ),
      ];

      await _pumpCard(tester, mediaItems: items);

      expect(find.text('1'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Image), findsWidgets);
    });
  });
}
