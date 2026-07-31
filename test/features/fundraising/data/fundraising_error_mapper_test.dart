import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/fundraising_error_mapper.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  group('mapFundraisingSafeError', () {
    // Session/Auth errors
    test('maps CENTRAL_TOKEN_EXPIRED to a session-expired category', () {
      final result = mapFundraisingSafeError(
        ApiClientException(
          message: 'jwt expired',
          statusCode: 401,
          code: 'CENTRAL_TOKEN_EXPIRED',
        ),
      );
      expect(result.isSessionExpired, isTrue);
      expect(result.message, contains('session has expired'));
      expect(result.statusCode, 401);
      expect(result.backendCode, 'CENTRAL_TOKEN_EXPIRED');
    });

    test('maps a 401 without a code to session-expired', () {
      final result = mapFundraisingSafeError(
        ApiClientException(message: 'unauthorized', statusCode: 401),
      );
      expect(result.isSessionExpired, isTrue);
      expect(result.statusCode, 401);
    });

    // Account Incomplete errors (NEW - Step 2)
    test(
      'maps 409 FUNDRAISING_ACCOUNT_INCOMPLETE to accountIncomplete category',
      () {
        final result = mapFundraisingSafeError(
          ApiClientException(
            message: 'Complete your verification profile',
            statusCode: 409,
            code: 'FUNDRAISING_ACCOUNT_INCOMPLETE',
            responseData: {
              'success': false,
              'code': 'FUNDRAISING_ACCOUNT_INCOMPLETE',
              'message': 'Complete your verification profile',
              'details': {
                'missingRequirements': ['presentAddress', 'documents'],
              },
            },
          ),
        );
        expect(result.isAccountIncomplete, isTrue);
        expect(result.statusCode, 409);
        expect(result.backendCode, 'FUNDRAISING_ACCOUNT_INCOMPLETE');
        expect(result.details, isNotNull);
        expect(result.missingRequirements, ['presentAddress', 'documents']);
      },
    );

    test('preserves missingRequirements in details for 409', () {
      final result = mapFundraisingSafeError(
        ApiClientException(
          message: 'Account incomplete',
          statusCode: 409,
          code: 'FUNDRAISING_ACCOUNT_INCOMPLETE',
          responseData: {
            'details': {
              'missingRequirements': ['dateOfBirth', 'location', 'documents'],
            },
          },
        ),
      );
      expect(result.missingRequirements, [
        'dateOfBirth',
        'location',
        'documents',
      ]);
    });

    // Account Rejected errors (NEW - Step 2)
    test('maps 403 FUNDRAISING_FORBIDDEN to accountRejected category', () {
      final result = mapFundraisingSafeError(
        ApiClientException(
          message: 'Your fundraising account has been rejected',
          statusCode: 403,
          code: 'FUNDRAISING_FORBIDDEN',
          responseData: {
            'message': 'Your fundraising account has been rejected',
          },
        ),
      );
      expect(result.isAccountRejected, isTrue);
      expect(result.statusCode, 403);
      expect(result.backendCode, 'FUNDRAISING_FORBIDDEN');
    });

    test('uses backend message for 403 FUNDRAISING_FORBIDDEN when available', () {
      final result = mapFundraisingSafeError(
        ApiClientException(
          message: 'Forbidden',
          statusCode: 403,
          code: 'FUNDRAISING_FORBIDDEN',
          responseData: {
            'message':
                'Your account was rejected due to policy violations. Contact support.',
          },
        ),
      );
      expect(result.message, contains('policy violations'));
    });

    // Fundraiser visibility/authorization typed errors
    test(
      'maps FUNDRAISER_NOT_FOUND (404) to notFound category, without distinguishing deleted vs private',
      () {
        final result = mapFundraisingSafeError(
          ApiClientException(
            message: 'Campaign not found',
            statusCode: 404,
            code: 'FUNDRAISER_NOT_FOUND',
          ),
        );
        expect(result.isNotFound, isTrue);
        expect(result.message, 'This fundraiser is unavailable.');
        expect(result.backendCode, 'FUNDRAISER_NOT_FOUND');
      },
    );

    test(
      'maps FUNDRAISER_NOT_PUBLIC (403) to notFound category, never revealing the private status',
      () {
        final result = mapFundraisingSafeError(
          ApiClientException(
            message: 'This fundraiser is not publicly available',
            statusCode: 403,
            code: 'FUNDRAISER_NOT_PUBLIC',
          ),
        );
        expect(result.isNotFound, isTrue);
        expect(result.message, 'This fundraiser is unavailable.');
      },
    );

    test(
      'maps FUNDRAISER_ACCESS_DENIED (403) to permissionDenied category',
      () {
        final result = mapFundraisingSafeError(
          ApiClientException(
            message: 'Campaign not found',
            statusCode: 403,
            code: 'FUNDRAISER_ACCESS_DENIED',
          ),
        );
        expect(result.isPermissionDenied, isTrue);
        expect(result.backendCode, 'FUNDRAISER_ACCESS_DENIED');
      },
    );

    test(
      'maps FUNDRAISER_EDIT_FORBIDDEN (403) to a distinct permission-denied message about editing',
      () {
        final result = mapFundraisingSafeError(
          ApiClientException(
            message: 'Campaign not found',
            statusCode: 403,
            code: 'FUNDRAISER_EDIT_FORBIDDEN',
          ),
        );
        expect(result.isPermissionDenied, isTrue);
        expect(result.message, contains('edit'));
      },
    );

    test(
      'maps FUNDRAISER_NOT_DONATABLE (422) to a distinct notDonatable category, not permissionDenied or notFound',
      () {
        final result = mapFundraisingSafeError(
          ApiClientException(
            message: 'This fundraiser has expired',
            statusCode: 422,
            code: 'FUNDRAISER_NOT_DONATABLE',
            responseData: {'message': 'This fundraiser has expired'},
          ),
        );
        expect(result.isNotDonatable, isTrue);
        expect(result.isNotFound, isFalse);
        expect(result.isPermissionDenied, isFalse);
        expect(result.message, 'This fundraiser has expired');
      },
    );

    // Schema Unavailable errors (NEW - Step 2)
    test('maps 503 FUNDRAISING_SCHEMA_UNAVAILABLE to schemaUnavailable', () {
      final result = mapFundraisingSafeError(
        ApiClientException(
          message: 'Service unavailable',
          statusCode: 503,
          code: 'FUNDRAISING_SCHEMA_UNAVAILABLE',
        ),
      );
      expect(result.isSchemaUnavailable, isTrue);
      expect(result.statusCode, 503);
      expect(result.backendCode, 'FUNDRAISING_SCHEMA_UNAVAILABLE');
      expect(result.message, contains('temporarily unavailable'));
    });

    // Server Failure errors (NEW - Step 2)
    test('maps 500 FUNDRAISING_REQUEST_FAILED to serverFailure', () {
      final result = mapFundraisingSafeError(
        ApiClientException(
          message: 'Internal server error',
          statusCode: 500,
          code: 'FUNDRAISING_REQUEST_FAILED',
        ),
      );
      expect(result.isServerFailure, isTrue);
      expect(result.statusCode, 500);
      expect(result.backendCode, 'FUNDRAISING_REQUEST_FAILED');
    });

    test('maps generic 5xx to serverFailure', () {
      final result = mapFundraisingSafeError(
        ApiClientException(message: 'internal error', statusCode: 502),
      );
      expect(result.isServerFailure, isTrue);
      expect(result.statusCode, 502);
    });

    // Validation errors
    test('maps 400 to validation category', () {
      final result = mapFundraisingSafeError(
        ApiClientException(
          message: 'Validation failed',
          statusCode: 400,
          code: 'FUNDRAISING_VALIDATION_ERROR',
          responseData: {
            'details': [
              {'path': 'title', 'message': 'Title is required'},
            ],
          },
        ),
      );
      expect(result.category, FundraisingErrorCategory.validation);
      expect(result.statusCode, 400);
    });

    test('maps 422 to validation category', () {
      final result = mapFundraisingSafeError(
        ApiClientException(message: 'Unprocessable entity', statusCode: 422),
      );
      expect(result.category, FundraisingErrorCategory.validation);
    });

    test('preserves the safe API message for plain validation errors', () {
      final message = mapFundraisingError(
        ApiClientException(
          message: 'Draft is incomplete: monthlyGoalMinor',
          statusCode: 400,
          code: 'VALIDATION_ERROR',
          responseData: {
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Draft is incomplete: monthlyGoalMinor',
            },
          },
        ),
      );

      expect(message, 'Draft is incomplete: monthlyGoalMinor');
    });

    // Network errors
    test(
      'maps a connection-error ApiClientException to a friendly retry message',
      () {
        final result = mapFundraisingSafeError(
          ApiClientException(
            message: 'Connection refused: 192.168.10.111:4000',
            dioExceptionType: 'connectionError',
          ),
        );

        expect(result.isNetwork, isTrue);
        expect(result.message, contains('Unable to connect'));
        expect(result.message, isNot(contains('192.168.10.111')));
        expect(result.message, isNot(contains('DioException')));
      },
    );

    for (final type in <String>[
      'connectionTimeout',
      'sendTimeout',
      'receiveTimeout',
    ]) {
      test('maps $type to a network-category friendly message', () {
        final result = mapFundraisingSafeError(
          ApiClientException(message: 'timed out', dioExceptionType: type),
        );
        expect(result.isNetwork, isTrue);
        expect(result.message, isNot(contains('Exception')));
      });
    }

    // Parse failures
    test('maps FormatException to parseFailure', () {
      final result = mapFundraisingSafeError(const FormatException('bad json'));
      expect(result.category, FundraisingErrorCategory.parseFailure);
    });

    test('maps FundraisingAccountParseException to parseFailure', () {
      final result = mapFundraisingSafeError(
        const FundraisingAccountParseException('parser.field expected numeric'),
      );
      expect(result.category, FundraisingErrorCategory.parseFailure);
    });

    // Safety checks - no leakage
    test('never surfaces a raw DioException.toString()', () {
      final dioError = DioException(
        requestOptions: RequestOptions(
          path: 'http://10.0.2.2:4000/fundraising/account/me',
        ),
        type: DioExceptionType.connectionError,
        error: const SocketException('Connection refused'),
      );
      final result = mapFundraisingSafeError(dioError);

      expect(result.isNetwork, isTrue);
      expect(result.message, isNot(contains('DioException')));
      expect(result.message, isNot(contains('SocketException')));
      expect(result.message, isNot(contains('10.0.2.2')));
      expect(result.message, isNot(contains('4000')));
    });

    test('never surfaces a raw SocketException.toString()', () {
      final result = mapFundraisingSafeError(
        const SocketException('Connection refused', address: null),
      );
      expect(result.isNetwork, isTrue);
      expect(result.message, isNot(contains('SocketException')));
    });

    test('falls back to a generic safe message for unknown errors', () {
      final result = mapFundraisingSafeError(
        Exception('{"internal":"detail"}'),
      );
      expect(result.message, isNot(contains('{')));
      expect(result.message, isNotEmpty);
    });

    // Code-first precedence - backend codes take precedence over HTTP status
    test('checks backend code BEFORE generic HTTP status categorization', () {
      // 409 normally could be a generic conflict, but with ACCOUNT_INCOMPLETE code
      // should be accountIncomplete category specifically
      final result = mapFundraisingSafeError(
        ApiClientException(
          message: 'Account incomplete',
          statusCode: 409,
          code: 'FUNDRAISING_ACCOUNT_INCOMPLETE',
          responseData: {
            'details': {
              'missingRequirements': ['presentAddress'],
            },
          },
        ),
      );
      expect(result.isAccountIncomplete, isTrue);
      expect(result.category, isNot(FundraisingErrorCategory.validation));
    });
  });

  group('FundraisingSafeError.missingRequirements', () {
    test('extracts missingRequirements from details', () {
      final error = FundraisingSafeError(
        category: FundraisingErrorCategory.accountIncomplete,
        message: 'Incomplete',
        details: {
          'missingRequirements': ['presentAddress', 'documents'],
        },
      );
      expect(error.missingRequirements, ['presentAddress', 'documents']);
    });

    test('returns null when details is null', () {
      final error = FundraisingSafeError(
        category: FundraisingErrorCategory.accountIncomplete,
        message: 'Incomplete',
      );
      expect(error.missingRequirements, isNull);
    });

    test('returns null when missingRequirements key is missing', () {
      final error = FundraisingSafeError(
        category: FundraisingErrorCategory.accountIncomplete,
        message: 'Incomplete',
        details: {'other': 'data'},
      );
      expect(error.missingRequirements, isNull);
    });
  });
}
