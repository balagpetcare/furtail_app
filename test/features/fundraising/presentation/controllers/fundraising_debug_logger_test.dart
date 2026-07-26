import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/fundraising_debug_logger.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  group('buildFundraisingRequestDebugLog', () {
    test('includes the operation, method, endpoint, and status metadata', () {
      final message = buildFundraisingRequestDebugLog(
        operation: 'fundraising.account.fetchMyAccount',
        method: 'GET',
        endpointPath: '/api/v1/fundraising/account/me',
        error: ApiClientException(
          message: 'Connection refused',
          statusCode: 404,
          code: 'FUNDRAISING_ACCOUNT_NOT_FOUND',
          dioExceptionType: 'badResponse',
        ),
        responseTopLevelKeys: const ['data', 'success'],
      );

      expect(message, isNotNull);
      expect(message, contains('operation=fundraising.account.fetchMyAccount'));
      expect(message, contains('method=GET'));
      expect(message, contains('endpoint=/api/v1/fundraising/account/me'));
      expect(message, contains('statusCode=404'));
      expect(message, contains('backendCode=FUNDRAISING_ACCOUNT_NOT_FOUND'));
      expect(message, contains('responseTopLevelKeys=[data, success]'));
      expect(message, contains('dioExceptionType=badResponse'));
      expect(message, contains('parsingExceptionType=n/a'));
    });

    test('handles a raw DioException without leaking host or port details', () {
      final message = buildFundraisingRequestDebugLog(
        operation: 'fundraising.account.fetchMyAccount',
        method: 'GET',
        endpointPath: '/api/v1/fundraising/account/me',
        error: DioException(
          requestOptions: RequestOptions(
            path: 'http://192.168.10.111:7200/api/v1/fundraising/account/me',
            method: 'GET',
          ),
          type: DioExceptionType.connectionError,
        ),
        responseTopLevelKeys: const [],
      );

      expect(message, isNotNull);
      expect(message, contains('dioExceptionType=connectionError'));
      expect(message, isNot(contains('192.168.10.111')));
      expect(message, isNot(contains('7200')));
    });

    test('includes the parsing exception type for malformed payloads', () {
      final message = buildFundraisingRequestDebugLog(
        operation: 'fundraising.account.fetchMyAccount',
        method: 'GET',
        endpointPath: '/api/v1/fundraising/account/me',
        error: const FundraisingAccountParseException('bad payload'),
        responseTopLevelKeys: const ['success'],
      );

      expect(
        message,
        contains('parsingExceptionType=FundraisingAccountParseException'),
      );
      expect(message, contains('backendCode=n/a'));
    });

    test('returns null for unrelated error types', () {
      expect(
        buildFundraisingRequestDebugLog(
          operation: 'fundraising.account.fetchMyAccount',
          method: 'GET',
          endpointPath: '/api/v1/fundraising/account/me',
          error: Exception('unrelated'),
        ),
        isNull,
      );
    });
  });
}
