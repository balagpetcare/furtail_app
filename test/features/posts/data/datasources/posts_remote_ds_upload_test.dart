import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/services/api_client.dart';

class _FakeAuthenticatedMediaUploader extends AuthenticatedMediaUploader {
  _FakeAuthenticatedMediaUploader() : super(client: ApiClient(dio: Dio()));

  Object? lastFile;
  Map<String, String>? lastFields;
  Map<String, String>? lastHeaders;
  void Function(int sentBytes, int totalBytes)? lastProgress;
  CancelToken? lastCancelToken;

  @override
  Future<UploadedMediaResult> upload({
    required Object file,
    Map<String, String> fields = const <String, String>{},
    Map<String, String>? headers,
    void Function(int sentBytes, int totalBytes)? onProgress,
    CancelToken? cancelToken,
  }) async {
    lastFile = file;
    lastFields = Map<String, String>.from(fields);
    lastHeaders = headers == null ? null : Map<String, String>.from(headers);
    lastProgress = onProgress;
    lastCancelToken = cancelToken;
    onProgress?.call(64, 128);
    return const UploadedMediaResult(
      id: 77,
      url: 'https://cdn.example.test/uploaded.jpg',
      type: 'IMAGE',
    );
  }
}

void main() {
  group('PostsRemoteDs upload delegation', () {
    test(
      'passes upload fields and progress callback through the shared uploader',
      () async {
        final fakeUploader = _FakeAuthenticatedMediaUploader();
        final ds = PostsRemoteDs(null, fakeUploader);
        final file = File(
          '${Directory.systemTemp.path}\\posts-ds-upload-test.jpg',
        );
        await file.writeAsBytes(<int>[1, 2, 3, 4]);
        final progressEvents = <String>[];

        final result = await ds.uploadMediaDetailedWithProgress(
          file,
          onProgress: (sent, total) => progressEvents.add('$sent/$total'),
          listingId: 12,
          draftId: 'draft-55',
          contentType: 'ADOPTION',
          contentId: 'draft-session-1',
          idempotencyKey: 'adoption:create:session-1:item-1',
          uploadContext: 'adoption',
          trimStartMs: 100,
          trimEndMs: 900,
          mute: true,
          volume: 0.75,
          coverTimestampMs: 250,
          aspectRatio: '4:5',
          quality: 'high',
        );

        expect(result.id, equals(77));
        expect(fakeUploader.lastFile, same(file));
        expect(
          fakeUploader.lastFields,
          equals(<String, String>{
            'listingId': '12',
            'draftId': 'draft-55',
            'contentType': 'ADOPTION',
            'contentId': 'draft-session-1',
            'uploadContext': 'adoption',
            'trimStartMs': '100',
            'trimEndMs': '900',
            'volume': '0.75',
            'mute': '1',
            'coverTimestampMs': '250',
            'aspectRatio': '4:5',
            'quality': 'high',
          }),
        );
        expect(
          fakeUploader.lastHeaders,
          equals(<String, String>{
            'Idempotency-Key': 'adoption:create:session-1:item-1',
          }),
        );
        expect(progressEvents, equals(<String>['64/128']));
      },
    );
  });
}
