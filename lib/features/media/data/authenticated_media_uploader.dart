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
  });

  final MediaUploadErrorKind kind;
  final String userMessage;
  final int? statusCode;
  final String? code;

  factory MediaUploadException.from(Object error) {
    if (error is MediaUploadException) {
      return error;
    }

    if (error is ApiClientException) {
      final code = error.code?.trim().toUpperCase();

      if (error.statusCode == 401 &&
          (code == 'CENTRAL_TOKEN_EXPIRED' || code == 'TOKEN_REVOKED')) {
        return MediaUploadException(
          kind: MediaUploadErrorKind.sessionExpired,
          userMessage: 'Your session has expired. Please sign in again.',
          statusCode: error.statusCode,
          code: code,
        );
      }

      if (error.isNetworkError) {
        return MediaUploadException(
          kind: MediaUploadErrorKind.networkTimeout,
          userMessage:
              'Upload timed out. Please check your connection and try again.',
          statusCode: error.statusCode,
          code: code,
        );
      }

      if (code == 'FILE_TOO_LARGE') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.fileTooLarge,
          userMessage: _sanitizeMessage(
            error.message,
            fallback:
                'The selected file is too large. Please choose a smaller file.',
          ),
          statusCode: error.statusCode,
          code: code,
        );
      }

      if (code == 'STORAGE_UPLOAD_FAILED') {
        return MediaUploadException(
          kind: MediaUploadErrorKind.storageFailure,
          userMessage:
              'We could not store that file right now. Please try again.',
          statusCode: error.statusCode,
          code: code,
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
          statusCode: error.statusCode,
          code: code,
        );
      }

      return MediaUploadException(
        kind: MediaUploadErrorKind.unknown,
        userMessage: _sanitizeMessage(
          error.message,
          fallback: 'Could not upload the file right now. Please try again.',
        ),
        statusCode: error.statusCode,
        code: code,
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
    if (message.startsWith('{') || message.startsWith('[')) return fallback;
    return message;
  }

  @override
  String toString() => userMessage;
}

class AuthenticatedMediaUploader {
  AuthenticatedMediaUploader({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<UploadedMediaResult> upload({
    required Object file,
    Map<String, String> fields = const <String, String>{},
    void Function(int sentBytes, int totalBytes)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _client.multipartPostTyped<UploadedMediaResult>(
        url: '${ApiConfig.apiV1}/media/upload',
        files: [ApiMultipartFilePart(fieldName: 'file', file: file)],
        fields: fields,
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
      mimeType: payload?['mimeType']?.toString() ?? payload?['mimetype']?.toString(),
    );
  }
}
