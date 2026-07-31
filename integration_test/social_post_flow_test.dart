import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:furtail_app/core/config/app_config.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/services/api_client.dart';

import 'e2e_test_harness.dart';

Future<E2eTestHarness> _bootHarness(WidgetTester tester) async {
  await waitForApiReady();
  final harness = await E2eTestHarness.install(
    subject: '1',
    email: 'amina@example.com',
    displayName: 'Amina',
  );
  await launchAuthenticatedApp(tester, harness.session);
  return harness;
}

Map<String, dynamic> _mapOf(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

Future<Map<String, dynamic>> _uploadMedia(
  ApiClient api, {
  required String filePath,
  required String contentId,
  required String idempotencyKey,
}) async {
  return _mapOf(
    await api.multipartPostTyped<Map<String, dynamic>>(
      url: '${AppConfig.apiV1}/media/upload',
      files: [ApiMultipartFilePart(fieldName: 'file', file: File(filePath))],
      fields: <String, String>{
        'contentType': 'social',
        'contentId': contentId,
        'idempotencyKey': idempotencyKey,
      },
      parse: (decoded) => _mapOf(decoded)['data'] as Map<String, dynamic>,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'social posts flow covers text/image/video creation, duplicate-media prevention, feed/detail, edit, reactions, comments, share link, owner delete, and non-owner denial',
    (tester) async {
      final harness = await _bootHarness(tester);
      try {
        final api = ApiClient();
        final posts = PostsRemoteDs();

        final imageUpload = await _uploadMedia(
          api,
          filePath: harness.artifacts.imagePath,
          contentId: 'social-image',
          idempotencyKey: 'social-image-1',
        );
        final duplicateImage = await _uploadMedia(
          api,
          filePath: harness.artifacts.imagePath,
          contentId: 'social-image',
          idempotencyKey: 'social-image-1',
        );
        expect(
          (duplicateImage['id'] as num).toInt(),
          (imageUpload['id'] as num).toInt(),
        );

        final videoUpload = await _uploadMedia(
          api,
          filePath: harness.artifacts.videoPath,
          contentId: 'social-video',
          idempotencyKey: 'social-video-1',
        );

        final textPost = await posts.createPost(
          type: 'TEXT',
          caption: 'E2E ${uniqueDataSuffix('text-post')}',
          privacy: 'PUBLIC',
        );
        expect(textPost.type, 'TEXT');

        final imagePost = await posts.createPost(
          type: 'IMAGE',
          caption: 'E2E ${uniqueDataSuffix('image-post')}',
          mediaIds: [(imageUpload['id'] as num).toInt()],
          privacy: 'PUBLIC',
        );
        expect(imagePost.media, isNotEmpty);

        final videoPost = await posts.createPost(
          type: 'VIDEO',
          caption: 'E2E ${uniqueDataSuffix('video-post')}',
          mediaIds: [(videoUpload['id'] as num).toInt()],
          privacy: 'PUBLIC',
        );
        expect(videoPost.media, isNotEmpty);

        final feed = await posts.getFeed(limit: 20);
        final feedIds = feed.map((post) => post.id).toSet();
        expect(feedIds, contains(textPost.id));
        expect(feedIds, contains(imagePost.id));
        expect(feedIds, contains(videoPost.id));

        final detail = await posts.getPostById(postId: imagePost.id);
        expect(detail.id, imagePost.id);

        final updated = await posts.updatePost(
          postId: imagePost.id,
          caption: 'Updated ${uniqueDataSuffix('caption')}',
          mediaIds: [(imageUpload['id'] as num).toInt()],
        );
        expect(updated.caption, startsWith('Updated'));

        final liked = await posts.likePost(imagePost.id);
        expect(liked, isNotNull);
        final commented = await posts.addComment(
          imagePost.id,
          'Nice post ${uniqueDataSuffix('comment')}',
        );
        expect(commented.text, startsWith('Nice post'));
        final replied = await posts.replyComment(
          postId: imagePost.id,
          commentId: commented.id,
          text: 'Thanks ${uniqueDataSuffix('reply')}',
        );
        expect(replied.parentId, commented.id);
        final shared = await posts.sharePost(imagePost.id);
        expect(shared, isNotEmpty);

        await posts.deletePost(postId: videoPost.id);

        final ownerSession = harness.session;
        final foreignSession = E2eTestSession(
          subject: '2',
          email: 'zara@example.com',
          displayName: 'Zara',
        );
        foreignSession.seed();
        try {
          try {
            await PostsRemoteDs().updatePost(
              postId: textPost.id,
              caption: 'Should be denied',
            );
            fail('Expected the non-owner update to be denied.');
          } catch (error) {
            expect(error.toString(), contains('403'));
          }

          try {
            await PostsRemoteDs().deletePost(postId: textPost.id);
            fail('Expected the non-owner delete to be denied.');
          } catch (error) {
            expect(error.toString(), contains('403'));
          }
        } finally {
          ownerSession.seed();
        }
      } finally {
        await harness.dispose();
      }
    },
  );
}
