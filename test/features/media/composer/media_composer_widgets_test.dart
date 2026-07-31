import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/media/composer/media_composer_controller.dart';
import 'package:furtail_app/features/media/composer/media_composer_policy.dart';
import 'package:furtail_app/features/media/composer/media_composer_widgets.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders media cards cleanly on a small screen', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final controller = MediaComposerController(
      policy: MediaComposerPolicy.fundraising,
      draftStorageKey: 'widget-layout',
      uploadMedia:
          (
            item, {
            void Function(int sentBytes, int totalBytes)? onProgress,
            CancelToken? cancelToken,
          }) async {
            throw UnimplementedError('upload is not used in this widget test');
          },
    );

    await controller.seedItemsIfEmpty(<MediaDraftItem>[
      const MediaDraftItem(
        id: 'remote-photo',
        type: MediaDraftType.image,
        fileName: 'hero-photo.jpg',
        originalSizeBytes: 2048,
        remoteMediaId: 101,
        remoteUrl: 'https://cdn.example.test/hero-photo.jpg',
        state: MediaDraftState.ready,
        progress: 1,
        isCover: true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: MediaComposerList(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(find.text('hero-photo.jpg'), findsOneWidget);
  });
}
