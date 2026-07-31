import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  group('MediaUploadException.from', () {
    test(
      'maps a 401 upload failure to unauthenticated and preserves requestId',
      () {
        final result = MediaUploadException.from(
          ApiClientException(
            message: 'Authentication required',
            statusCode: 401,
            code: 'AUTHENTICATION_REQUIRED',
            responseData: {
              'meta': {'requestId': 'req-upload-1'},
            },
          ),
        );

        expect(result.kind, MediaUploadErrorKind.unauthenticated);
        expect(result.requestId, 'req-upload-1');
        expect(result.userMessage, isNot(contains('Authentication required')));
      },
    );

    test('maps MEDIA_BINDING_CONFLICT to a retry-safe conflict state', () {
      final result = MediaUploadException.from(
        ApiClientException(
          message: 'Document already attached',
          statusCode: 409,
          code: 'MEDIA_BINDING_CONFLICT',
        ),
      );

      expect(result.kind, MediaUploadErrorKind.mediaBindingConflict);
      expect(result.code, 'MEDIA_BINDING_CONFLICT');
    });

    test(
      'sanitizes raw internal server errors into a retryable upload failure',
      () {
        final result = MediaUploadException.from(
          ApiClientException(
            message: 'Internal server error',
            statusCode: 500,
            code: 'INTERNAL_ERROR',
            responseData: {
              'meta': {'requestId': 'req-upload-2'},
            },
          ),
        );

        expect(result.kind, MediaUploadErrorKind.retryableUploadFailure);
        expect(result.requestId, 'req-upload-2');
        expect(result.userMessage, isNot(contains('Internal server error')));
        expect(result.userMessage, isNot(contains('stack trace')));
      },
    );

    test('maps MEDIA_NOT_OWNED to an owner-bound failure', () {
      final result = MediaUploadException.from(
        ApiClientException(
          message: 'Media not found',
          statusCode: 403,
          code: 'MEDIA_NOT_OWNED',
        ),
      );

      expect(result.kind, MediaUploadErrorKind.mediaNotOwned);
      expect(result.userMessage, contains('upload them again'));
    });

    test('maps MEDIA_NOT_FOUND to the same owner-bound failure', () {
      final result = MediaUploadException.from(
        ApiClientException(
          message: 'Media not found',
          statusCode: 404,
          code: 'MEDIA_NOT_FOUND',
        ),
      );

      expect(result.kind, MediaUploadErrorKind.mediaNotOwned);
      expect(
        result.userMessage,
        'One or more uploaded files are unavailable. Please upload them again.',
      );
    });
  });
}
