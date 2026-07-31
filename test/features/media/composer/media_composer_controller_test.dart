import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/media/composer/media_composer_controller.dart';
import 'package:furtail_app/features/media/composer/media_composer_policy.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaComposerController', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp(
        'media-composer-controller-test-',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'supports mixed fundraiser media without clearing existing items',
      () async {
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'mixed',
          uploadMedia: _successfulUpload,
        );

        await controller.addItems(<MediaDraftItem>[
          _imageItem(await _file(tempDir, 'photo.jpg')),
          _videoItem(await _file(tempDir, 'clip.mp4')),
          _documentItem(await _file(tempDir, 'proof.pdf')),
        ]);

        expect(controller.items, hasLength(3));
        expect(controller.items.where((item) => item.isImage), hasLength(1));
        expect(controller.items.where((item) => item.isVideo), hasLength(1));
        expect(controller.items.where((item) => item.isDocument), hasLength(1));
      },
    );

    test(
      'shares one upload queue across concurrent ensureUploaded calls',
      () async {
        var uploads = 0;
        final item = _imageItem(await _file(tempDir, 'queue.jpg'));
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'queue',
          uploadMedia: (media, {onProgress, cancelToken}) async {
            uploads += 1;
            return _successfulUpload(
              media,
              onProgress: onProgress,
              cancelToken: cancelToken,
            );
          },
        );

        await controller.addItems(<MediaDraftItem>[item]);
        final results = await Future.wait<List<int>>(<Future<List<int>>>[
          controller.ensureUploaded(),
          controller.ensureUploaded(),
        ]);

        expect(uploads, 1);
        expect(results, everyElement(isNotEmpty));
        expect(controller.allItemsReady, isTrue);
      },
    );

    test(
      'retry uploads only the failed item and keeps successful uploads',
      () async {
        var attempts = 0;
        final photo = _imageItem(await _file(tempDir, 'photo.jpg'));
        final proof = _documentItem(await _file(tempDir, 'proof.pdf'));
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'retry',
          uploadMedia: (item, {onProgress, cancelToken}) async {
            if (item.id == proof.id && attempts++ == 0) {
              throw const MediaUploadException(
                kind: MediaUploadErrorKind.storageFailure,
                userMessage: 'Please retry the failed upload.',
              );
            }
            return _successfulUpload(
              item,
              onProgress: onProgress,
              cancelToken: cancelToken,
            );
          },
        );

        await controller.addItems(<MediaDraftItem>[photo, proof]);
        await expectLater(
          controller.ensureUploaded(),
          throwsA(isA<MediaUploadException>()),
        );
        expect(
          controller.items
              .singleWhere((item) => item.id == photo.id)
              .remoteMediaId,
          isNotNull,
        );
        expect(
          controller.items.singleWhere((item) => item.id == proof.id).state,
          MediaDraftState.failed,
        );

        await controller.retryItem(proof.id);

        final retried = controller.items.singleWhere(
          (item) => item.id == proof.id,
        );
        expect(retried.remoteMediaId, isNotNull);
        expect(
          retried.state,
          anyOf(MediaDraftState.ready, MediaDraftState.processing),
        );
      },
    );

    test(
      'cancels an in-flight item without affecting completed uploads',
      () async {
        final first = _imageItem(await _file(tempDir, 'first.jpg'));
        final second = _videoItem(await _file(tempDir, 'second.mp4'));
        final gate = Completer<void>();
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'cancel',
          uploadMedia: (item, {onProgress, cancelToken}) async {
            if (item.id == first.id) {
              await Future.any<void>(<Future<void>>[
                gate.future,
                cancelToken?.whenCancel.then((_) {}) ?? Future<void>.value(),
              ]);
            }
            if (cancelToken?.isCancelled ?? false) {
              throw const MediaUploadException(
                kind: MediaUploadErrorKind.requestCancelled,
                userMessage: 'Upload cancelled.',
              );
            }
            return _successfulUpload(
              item,
              onProgress: onProgress,
              cancelToken: cancelToken,
            );
          },
        );

        await controller.addItems(<MediaDraftItem>[first, second]);
        final uploadFuture = controller.ensureUploaded();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await controller.cancelItem(first.id);
        gate.complete();

        await expectLater(uploadFuture, throwsA(isA<MediaUploadException>()));
        expect(
          controller.items.singleWhere((item) => item.id == first.id).state,
          MediaDraftState.cancelled,
        );
        expect(
          controller.items
              .singleWhere((item) => item.id == second.id)
              .remoteMediaId,
          isNotNull,
        );
      },
    );

    test('reorders items and promotes the chosen cover media', () async {
      final first = _imageItem(await _file(tempDir, 'first.jpg'));
      final second = _imageItem(await _file(tempDir, 'second.jpg'));
      final third = _documentItem(await _file(tempDir, 'third.pdf'));
      final controller = MediaComposerController(
        policy: MediaComposerPolicy.fundraising,
        draftStorageKey: 'reorder',
        uploadMedia: _successfulUpload,
      );

      await controller.addItems(<MediaDraftItem>[first, second, third]);
      await controller.reorder(0, 3);
      expect(controller.items.map((item) => item.id), <String>[
        second.id,
        third.id,
        first.id,
      ]);
      expect(controller.items.first.isCover, isTrue);

      await controller.setCover(first.id);
      expect(controller.items.first.id, first.id);
      expect(controller.items.first.isCover, isTrue);
    });

    test(
      'partial failure blocks submission but preserves completed uploads',
      () async {
        final good = _imageItem(await _file(tempDir, 'good.jpg'));
        final bad = _documentItem(await _file(tempDir, 'bad.pdf'));
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'partial',
          uploadMedia: (item, {onProgress, cancelToken}) async {
            if (item.id == bad.id) {
              throw const MediaUploadException(
                kind: MediaUploadErrorKind.fileTooLarge,
                userMessage: 'Choose a smaller file.',
              );
            }
            return _successfulUpload(
              item,
              onProgress: onProgress,
              cancelToken: cancelToken,
            );
          },
        );

        await controller.addItems(<MediaDraftItem>[good, bad]);
        await expectLater(
          controller.ensureUploaded(),
          throwsA(isA<MediaUploadException>()),
        );

        expect(
          controller.items
              .singleWhere((item) => item.id == good.id)
              .remoteMediaId,
          isNotNull,
        );
        expect(
          controller.items.singleWhere((item) => item.id == bad.id).state,
          MediaDraftState.failed,
        );
      },
    );

    test('failed item blocks submission', () async {
      final broken = _documentItem(await _file(tempDir, 'broken.pdf'));
      final controller = MediaComposerController(
        policy: MediaComposerPolicy.fundraising,
        draftStorageKey: 'blocks-submission',
        uploadMedia: (item, {onProgress, cancelToken}) async {
          throw const MediaUploadException(
            kind: MediaUploadErrorKind.storageFailure,
            userMessage: 'Please retry the failed upload.',
          );
        },
      );

      await controller.addItems(<MediaDraftItem>[broken]);
      await expectLater(
        controller.ensureUploaded(),
        throwsA(isA<MediaUploadException>()),
      );

      expect(controller.hasFailedItems, isTrue);
      expect(controller.hasBlockingItems, isTrue);
      expect(controller.mediaValidation.canContinue, isFalse);
    });

    test(
      'one successful image enables Continue once the upload settles',
      () async {
        final photo = _imageItem(await _file(tempDir, 'ready.jpg'));
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'continue-ready',
          uploadMedia: _successfulUpload,
        );

        await controller.addItems(<MediaDraftItem>[photo]);
        await controller.ensureUploaded();

        expect(controller.mediaValidation.canContinue, isTrue);
        expect(controller.allItemsReady, isTrue);
        expect(controller.remoteMediaIds, hasLength(1));
      },
    );

    test('retry transitions failed to uploading to ready', () async {
      final observedStates = <MediaDraftState>[];
      var attempts = 0;
      final item = _imageItem(await _file(tempDir, 'flaky.jpg'));
      final controller = MediaComposerController(
        policy: MediaComposerPolicy.fundraising,
        draftStorageKey: 'retry-transitions',
        uploadMedia: (media, {onProgress, cancelToken}) async {
          attempts += 1;
          if (attempts == 1) {
            throw const MediaUploadException(
              kind: MediaUploadErrorKind.storageFailure,
              userMessage: 'Please retry the failed upload.',
            );
          }
          return _successfulUpload(
            media,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        },
      );

      await controller.addItems(<MediaDraftItem>[item]);
      await expectLater(
        controller.ensureUploaded(),
        throwsA(isA<MediaUploadException>()),
      );
      expect(controller.items.single.state, MediaDraftState.failed);

      controller.addListener(() {
        observedStates.add(controller.items.single.state);
      });
      await controller.retryItem(item.id);

      expect(observedStates, contains(MediaDraftState.uploading));
      expect(controller.items.single.state, MediaDraftState.ready);
    });

    test('removing failed item recalculates validation', () async {
      final good = _imageItem(await _file(tempDir, 'good.jpg'));
      final broken = _documentItem(await _file(tempDir, 'broken.pdf'));
      final controller = MediaComposerController(
        policy: MediaComposerPolicy.fundraising,
        draftStorageKey: 'remove-recalculates',
        uploadMedia: (item, {onProgress, cancelToken}) async {
          if (item.id == broken.id) {
            throw const MediaUploadException(
              kind: MediaUploadErrorKind.storageFailure,
              userMessage: 'Please retry the failed upload.',
            );
          }
          return _successfulUpload(
            item,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        },
      );

      await controller.addItems(<MediaDraftItem>[good, broken]);
      await expectLater(
        controller.ensureUploaded(),
        throwsA(isA<MediaUploadException>()),
      );
      expect(controller.mediaValidation.canContinue, isFalse);

      await controller.removeItem(broken.id);

      expect(controller.hasFailedItems, isFalse);
      expect(controller.mediaValidation.canContinue, isTrue);
    });

    test('activeUploadCount returns to zero once uploads settle', () async {
      final first = _imageItem(await _file(tempDir, 'first.jpg'));
      final second = _imageItem(await _file(tempDir, 'second.jpg'));
      final controller = MediaComposerController(
        policy: MediaComposerPolicy.fundraising,
        draftStorageKey: 'active-upload-count',
        uploadMedia: _successfulUpload,
      );

      await controller.addItems(<MediaDraftItem>[first, second]);
      await controller.ensureUploaded();

      expect(controller.activeUploadCount, 0);
    });

    test('duplicate retry does not start a second upload', () async {
      var uploadCalls = 0;
      final gate = Completer<void>();
      final item = _imageItem(await _file(tempDir, 'pending.jpg'));
      final controller = MediaComposerController(
        policy: MediaComposerPolicy.fundraising,
        draftStorageKey: 'duplicate-retry',
        uploadMedia: (media, {onProgress, cancelToken}) async {
          uploadCalls += 1;
          await gate.future;
          return _successfulUpload(
            media,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        },
      );

      await controller.addItems(<MediaDraftItem>[item]);
      final firstRetry = controller.retryItem(item.id);
      final secondRetry = controller.retryItem(item.id);
      gate.complete();
      await Future.wait<void>(<Future<void>>[firstRetry, secondRetry]);

      expect(uploadCalls, 1);
    });

    test('disposal cancels in-flight upload tasks', () async {
      var wasCancelledBeforeCompletion = false;
      final gate = Completer<void>();
      final item = _imageItem(await _file(tempDir, 'cancel-on-dispose.jpg'));
      final controller = MediaComposerController(
        policy: MediaComposerPolicy.fundraising,
        draftStorageKey: 'disposal-cancels',
        uploadMedia: (media, {onProgress, cancelToken}) async {
          await Future.any<void>(<Future<void>>[
            gate.future,
            cancelToken?.whenCancel ?? Future<void>.value(),
          ]);
          if (cancelToken?.isCancelled ?? false) {
            wasCancelledBeforeCompletion = true;
            throw const MediaUploadException(
              kind: MediaUploadErrorKind.requestCancelled,
              userMessage: 'Upload cancelled.',
            );
          }
          return _successfulUpload(
            media,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        },
      );

      await controller.addItems(<MediaDraftItem>[item]);
      final uploadFuture = controller.ensureUploaded();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      controller.dispose();
      gate.complete();

      await expectLater(uploadFuture, throwsA(isA<MediaUploadException>()));
      expect(wasCancelledBeforeCompletion, isTrue);
    });

    test(
      'restores persisted draft items and keeps uploaded ids on reopen',
      () async {
        final localFile = await _file(tempDir, 'draft.jpg');
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'restore',
          uploadMedia: _successfulUpload,
        );
        await controller.addItems(<MediaDraftItem>[
          _imageItem(localFile),
          MediaDraftItem(
            id: 'remote-doc',
            type: MediaDraftType.document,
            localPath: localFile.path,
            fileName: 'remote.pdf',
            originalSizeBytes: 99,
            remoteMediaId: 404,
            remoteUrl: 'https://cdn.example.test/remote.pdf',
            state: MediaDraftState.ready,
            progress: 1,
          ),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final reopened = MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'restore',
          uploadMedia: _successfulUpload,
        );
        await reopened.restore();

        expect(reopened.items, hasLength(2));
        expect(reopened.items.any((item) => item.remoteMediaId == 404), isTrue);
        expect(reopened.items.first.isCover, isTrue);
      },
    );

    test(
      'separate create sessions do not restore each other\'s media',
      () async {
        const sessionOneKey = 'adoption:create:session-one';
        const sessionTwoKey = 'adoption:create:session-two';
        SharedPreferences.setMockInitialValues(<String, Object>{
          'media_composer.$sessionOneKey':
              MediaDraftItem.encodeList(<MediaDraftItem>[
                MediaDraftItem(
                  id: 'restored-1',
                  type: MediaDraftType.image,
                  fileName: 'restored-1.jpg',
                  originalSizeBytes: 4,
                  state: MediaDraftState.ready,
                  remoteMediaId: 101,
                ),
              ]),
        });

        final first = MediaComposerController(
          policy: MediaComposerPolicy.adoption,
          draftStorageKey: sessionOneKey,
          uploadMedia: _successfulUpload,
        );
        await first.restore();
        expect(first.items, hasLength(1));

        final second = MediaComposerController(
          policy: MediaComposerPolicy.adoption,
          draftStorageKey: sessionTwoKey,
          uploadMedia: _successfulUpload,
        );
        await second.restore();
        expect(second.items, isEmpty);
      },
    );

    test(
      'reset clears only the current session draft and persisted media',
      () async {
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.adoption,
          draftStorageKey: 'adoption:create:reset-session',
          uploadMedia: _successfulUpload,
        );

        await controller.addItems(<MediaDraftItem>[
          _imageItem(await _file(tempDir, 'reset.jpg')),
        ]);
        expect(controller.items, hasLength(1));

        await controller.reset();
        expect(controller.items, isEmpty);

        final reopened = MediaComposerController(
          policy: MediaComposerPolicy.adoption,
          draftStorageKey: 'adoption:create:reset-session',
          uploadMedia: _successfulUpload,
        );
        await reopened.restore();
        expect(reopened.items, isEmpty);
      },
    );

    test(
      'removing a local item does not invoke the uploader or any delete path',
      () async {
        var uploadCalls = 0;
        final controller = MediaComposerController(
          policy: MediaComposerPolicy.adoption,
          draftStorageKey: 'adoption:create:remove-local',
          uploadMedia: (item, {onProgress, cancelToken}) async {
            uploadCalls += 1;
            return _successfulUpload(
              item,
              onProgress: onProgress,
              cancelToken: cancelToken,
            );
          },
        );

        final item = _imageItem(await _file(tempDir, 'remove-local.jpg'));
        await controller.addItems(<MediaDraftItem>[item]);
        await controller.removeItem(item.id);

        expect(controller.items, isEmpty);
        expect(uploadCalls, 0);
      },
    );
  });
}

Future<File> _file(Directory dir, String name) async {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(<int>[1, 2, 3, 4, 5]);
  return file;
}

MediaDraftItem _imageItem(File file) {
  return MediaDraftItem.image(
    id: 'image-${file.path.hashCode}',
    localPath: file.path,
    fileName: file.path.split(Platform.pathSeparator).last,
    originalSizeBytes: file.lengthSync(),
  );
}

MediaDraftItem _videoItem(File file) {
  return MediaDraftItem.video(
    id: 'video-${file.path.hashCode}',
    localPath: file.path,
    fileName: file.path.split(Platform.pathSeparator).last,
    originalSizeBytes: file.lengthSync(),
    thumbnailPath: file.path,
  );
}

MediaDraftItem _documentItem(File file) {
  return MediaDraftItem.document(
    id: 'doc-${file.path.hashCode}',
    localPath: file.path,
    fileName: file.path.split(Platform.pathSeparator).last,
    originalSizeBytes: file.lengthSync(),
  );
}

Future<UploadedMediaResult> _successfulUpload(
  MediaDraftItem item, {
  void Function(int sentBytes, int totalBytes)? onProgress,
  CancelToken? cancelToken,
}) async {
  onProgress?.call(50, 100);
  onProgress?.call(100, 100);
  return UploadedMediaResult(
    id: item.id.hashCode.abs(),
    url: 'https://cdn.example.test/${item.fileName}',
    thumbnailUrl: item.isVideo
        ? 'https://cdn.example.test/thumb-${item.fileName}.jpg'
        : null,
    type: item.isVideo ? 'VIDEO' : (item.isDocument ? 'DOCUMENT' : 'IMAGE'),
    status: item.isVideo ? 'PROCESSING' : 'READY',
  );
}
