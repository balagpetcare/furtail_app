import 'dart:io';

import 'package:dio/dio.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/core/network/api_config.dart';

class UploadedMediaResult {
  const UploadedMediaResult({
    required this.id,
    this.url,
    this.hlsUrl,
    this.thumbnailUrl,
    this.type,
    this.status,
    this.mimeType,
  });

  final int id;
  final String? url;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? type;
  final String? status;
  final String? mimeType;

  String? get previewUrl {
    final hls = hlsUrl?.trim();
    if (hls != null && hls.isNotEmpty) return hls;
    final direct = url?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return null;
  }
}

enum MediaUploadErrorKind {
  sessionExpired,
  unauthenticated,
  forbidden,
  mediaNotOwned,
  mediaBindingConflict,
  uploadIncomplete,
  invalidDraftState,
  retryableUploadFailure,
  networkTimeout,
  fileTooLarge,
  storageFailure,
  requestCancelled,
  invalidPayload,
  unknown,
}

class MediaUploadException implements Exception {
  const MediaUploadException({
    required this.kind,
    required this.userMessage,
    this.statusCode,
    this.code,
    this.requestId,
  });

  final MediaUploadErrorKind kind;
  final String userMessage;
  final int? statusCode;
  final String? code;
  final String? requestId;

  factory MediaUploadException.from(Object error) {
    if (error is MediaUploadException) {
      return error;
    }

    if (error is ApiClientException) {
      final code = error.code?.trim().toUpperCase();
      final statusCode = error.statusCode ?? 0;
      final requestId = _requestIdFromError(error);

      if (statusCode == 401 &&
          (code == 'CENTRAL_TOKEN_EXPIRED' || code == 'TOKEN_REVOKED')) {
        return MediaUploadException(
          kind: MediaUploadErrorKind.sessionExpired,
          userMessage: 'Your session has expired. Please sign in again.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (statusCode == 401) {
        return MediaUploadException(
          kind: MediaUploadErrorKind.unauthenticated,
          userMessage: 'Please sign in again to upload media.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (error.isNetworkError) {
        return MediaUploadException(
          kind: MediaUploadErrorKind.networkTimeout,
          userMessage:
              'Upload timed out. Please check your connection and try again.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'FILE_TOO_LARGE' || code == 'MEDIA_SIZE_EXCEEDED') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.fileTooLarge,
          userMessage: _sanitizeMessage(
            error.message,
            fallback:
                'The selected file is too large. Please choose a smaller file.',
          ),
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'UNSUPPORTED_MEDIA_TYPE' ||
          code == 'MEDIA_TYPE_UNSUPPORTED') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.invalidPayload,
          userMessage:
              'This file type is not supported. Please choose a different file.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'STORAGE_UPLOAD_FAILED') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.storageFailure,
          userMessage:
              'We could not store that file right now. Please try again.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'INVALID_MULTIPART_PAYLOAD' ||
          code == 'UPLOAD_FILE_MISSING' ||
          code == 'UPLOAD_FILE_TYPE_BLOCKED') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.invalidPayload,
          userMessage: _sanitizeMessage(
            error.message,
            fallback:
                'This file could not be uploaded. Please try another one.',
          ),
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'FORBIDDEN' || code == 'MEDIA_UPLOAD_FORBIDDEN') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.forbidden,
          userMessage:
              'You do not have permission to upload or attach this media.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'MEDIA_NOT_OWNED' || code == 'MEDIA_NOT_FOUND') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.mediaNotOwned,
          userMessage:
              'One or more uploaded files are unavailable. Please upload them again.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'MEDIA_BINDING_CONFLICT') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.mediaBindingConflict,
          userMessage: 'That file is already attached to this fundraiser.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'UPLOAD_INCOMPLETE') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.uploadIncomplete,
          userMessage: 'The upload did not finish. Please retry the file.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'INVALID_DRAFT_STATE') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.invalidDraftState,
          userMessage:
              'This fundraiser draft can no longer accept media changes.',
          statusCode: statusCode,
          code: code,
          requestId: requestId,
        );
      }

      if (code == 'RETRYABLE_UPLOAD_FAILURE' || statusCode >= 500) {
        return MediaUploadException(
          kind: MediaUploadErrorKind.retryableUploadFailure,
          userMessage: _sanitizeMessage(
            error.message,
            fallback:
                'We could not upload that file right now. Please try again.',
          ),
          statusCode: statusCode == 0 ? null : statusCode,
          code: code,
          requestId: requestId,
        );
      }

      return MediaUploadException(
        kind: MediaUploadErrorKind.unknown,
        userMessage: _sanitizeMessage(
          error.message,
          fallback: 'Could not upload the file right now. Please try again.',
        ),
        statusCode: statusCode == 0 ? null : statusCode,
        code: code,
        requestId: requestId,
      );
    }

    if (error is DioException) {
      if (error.type == DioExceptionType.cancel) {
        return const MediaUploadException(
          kind: MediaUploadErrorKind.requestCancelled,
          userMessage: 'Upload cancelled.',
        );
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        return const MediaUploadException(
          kind: MediaUploadErrorKind.networkTimeout,
          userMessage:
              'Upload timed out. Please check your connection and try again.',
        );
      }
    }

    if (error is SocketException) {
      return const MediaUploadException(
        kind: MediaUploadErrorKind.networkTimeout,
        userMessage:
            'Upload timed out. Please check your connection and try again.',
      );
    }

    return MediaUploadException(
      kind: MediaUploadErrorKind.unknown,
      userMessage: _sanitizeMessage(
        error.toString(),
        fallback: 'Could not upload the file right now. Please try again.',
      ),
    );
  }

  static String _sanitizeMessage(String? raw, {required String fallback}) {
    final message = (raw ?? '').replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) return fallback;
    final normalized = message.toLowerCase();
    if (message.startsWith('{') || message.startsWith('[')) return fallback;
    if (normalized.contains('prisma') ||
        normalized.contains('dioexception') ||
        normalized.contains('socketexception') ||
        normalized.contains('invalid image data') ||
        normalized.contains('stack trace') ||
        normalized.contains('sqlstate') ||
        normalized.contains('postgres') ||
        normalized.contains('internal server error') ||
        normalized == 'api error' ||
        normalized == 'upload error') {
      return fallback;
    }
    return message;
  }

  static String? _requestIdFromError(ApiClientException error) {
    final responseData = error.responseData;
    if (responseData is Map) {
      final meta = responseData['meta'];
      if (meta is Map) {
        final requestId = meta['requestId']?.toString().trim();
        if (requestId != null && requestId.isNotEmpty) return requestId;
      }
    }
    final headerValues =
        error.responseHeaders?['x-request-id'] ??
        error.responseHeaders?['X-Request-Id'];
    if (headerValues != null && headerValues.isNotEmpty) {
      final headerRequestId = headerValues.first.trim();
      if (headerRequestId.isNotEmpty) return headerRequestId;
    }
    return null;
  }

  @override
  String toString() {
    final parts = <String>[
      'kind=$kind',
      if (statusCode != null) 'statusCode=$statusCode',
      if (code != null && code!.isNotEmpty) 'code=$code',
      if (requestId != null && requestId!.isNotEmpty) 'requestId=$requestId',
      'message=${userMessage.replaceAll('\n', ' ').trim()}',
    ];
    return 'MediaUploadException(${parts.join(', ')})';
  }
}

class AuthenticatedMediaUploader {
  AuthenticatedMediaUploader({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<UploadedMediaResult> upload({
    required Object file,
    Map<String, String> fields = const <String, String>{},
    Map<String, String>? headers,
    void Function(int sentBytes, int totalBytes)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _client.multipartPostTyped<UploadedMediaResult>(
        url: '${ApiConfig.apiV1}/media/upload',
        files: [ApiMultipartFilePart(fieldName: 'file', file: file)],
        fields: fields,
        headers: headers,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
        parse: _decodeUploadedMedia,
      );
    } catch (error) {
      throw MediaUploadException.from(error);
    }
  }

  UploadedMediaResult _decodeUploadedMedia(dynamic decoded) {
    final body = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    final data = body?['data'];
    final payload = data is Map ? Map<String, dynamic>.from(data) : null;
    final mediaId = payload?['id'];

    if (mediaId is! num) {
      throw const MediaUploadException(
        kind: MediaUploadErrorKind.unknown,
        userMessage: 'Upload succeeded but the server response was incomplete.',
      );
    }

    return UploadedMediaResult(
      id: mediaId.toInt(),
      url: payload?['url']?.toString(),
      hlsUrl: payload?['hlsUrl']?.toString(),
      thumbnailUrl: payload?['thumbnailUrl']?.toString(),
      type: payload?['type']?.toString(),
      status: payload?['status']?.toString(),
      mimeType:
          payload?['mimeType']?.toString() ?? payload?['mimetype']?.toString(),
    );
  }
}
