import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:furtail_app/services/api_client.dart';
import 'models/fundraising_models.dart';

String? buildFundraisingRequestDebugLog({
  required String operation,
  required String method,
  required String endpointPath,
  required Object error,
  List<String>? responseTopLevelKeys,
}) {
  String statusCode = 'n/a';
  String backendCode = 'n/a';
  String requestId = 'n/a';
  String dioExceptionType = 'n/a';
  String parsingExceptionType = 'n/a';
  final keys = responseTopLevelKeys == null || responseTopLevelKeys.isEmpty
      ? 'n/a'
      : '[${responseTopLevelKeys.join(', ')}]';

  if (error is ApiClientException) {
    statusCode = (error.statusCode ?? 'n/a').toString();
    backendCode = (error.code ?? 'n/a').toString();
    dioExceptionType = (error.dioExceptionType ?? 'n/a').toString();
    final headers = error.responseHeaders;
    final values = headers?['x-request-id'] ?? headers?['X-Request-Id'];
    if (values != null && values.isNotEmpty) {
      requestId = values.first.toString();
    }
  } else if (error is DioException) {
    statusCode = (error.response?.statusCode ?? 'n/a').toString();
    dioExceptionType = error.type.name;
    final values = error.response?.headers.map['x-request-id'];
    if (values != null && values.isNotEmpty) {
      requestId = values.first.toString();
    }
  } else if (error is FundraisingAccountParseException) {
    parsingExceptionType = error.runtimeType.toString();
  } else {
    return null;
  }

  return 'Fundraising request failed: '
      'operation=$operation '
      'method=$method '
      'endpoint=$endpointPath '
      'statusCode=$statusCode '
      'backendCode=$backendCode '
      'requestId=$requestId '
      'responseTopLevelKeys=$keys '
      'dioExceptionType=$dioExceptionType '
      'parsingExceptionType=$parsingExceptionType';
}

void logFundraisingRequestDebug({
  required String operation,
  required String method,
  required String endpointPath,
  required Object error,
  List<String>? responseTopLevelKeys,
}) {
  if (!kDebugMode) return;
  final message = buildFundraisingRequestDebugLog(
    operation: operation,
    method: method,
    endpointPath: endpointPath,
    error: error,
    responseTopLevelKeys: responseTopLevelKeys,
  );
  if (message != null) {
    developer.log(message, name: 'Fundraising');
  }
}
