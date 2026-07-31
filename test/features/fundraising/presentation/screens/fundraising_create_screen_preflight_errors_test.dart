import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/fundraising_error_mapper.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FundraisingCreateScreen - Preflight Error States', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets(
      '409 FUNDRAISING_ACCOUNT_INCOMPLETE shows actionable requirements',
      (tester) async {
        final error = ApiClientException(
          message: 'Account incomplete',
          statusCode: 409,
          code: 'FUNDRAISING_ACCOUNT_INCOMPLETE',
          responseData: {
            'details': {
              'missingRequirements': ['presentAddress', 'documents'],
            },
          },
        );

        final mapped = mapFundraisingSafeError(error);

        expect(mapped.isAccountIncomplete, isTrue);
        expect(mapped.statusCode, 409);
        expect(mapped.backendCode, 'FUNDRAISING_ACCOUNT_INCOMPLETE');
        expect(mapped.missingRequirements, ['presentAddress', 'documents']);
        expect(mapped.message, contains('Complete your'));
        expect(mapped.message, isNot(contains('Verification unavailable')));
      },
    );

    testWidgets('403 FUNDRAISING_FORBIDDEN shows as rejected account', (
      tester,
    ) async {
      final error = ApiClientException(
        message: 'Rejected',
        statusCode: 403,
        code: 'FUNDRAISING_FORBIDDEN',
        responseData: {
          'message': 'Your account was rejected. Please contact support.',
        },
      );

      final mapped = mapFundraisingSafeError(error);

      expect(mapped.isAccountRejected, isTrue);
      expect(mapped.statusCode, 403);
      expect(mapped.backendCode, 'FUNDRAISING_FORBIDDEN');
      expect(mapped.message, contains('rejected'));
      expect(mapped.message, isNot(contains('under review')));
      expect(mapped.message, isNot(contains('Verification unavailable')));
    });

    testWidgets('503 FUNDRAISING_SCHEMA_UNAVAILABLE shows as schema issue', (
      tester,
    ) async {
      final error = ApiClientException(
        message: 'Service unavailable',
        statusCode: 503,
        code: 'FUNDRAISING_SCHEMA_UNAVAILABLE',
      );

      final mapped = mapFundraisingSafeError(error);

      expect(mapped.isSchemaUnavailable, isTrue);
      expect(mapped.statusCode, 503);
      expect(mapped.backendCode, 'FUNDRAISING_SCHEMA_UNAVAILABLE');
      expect(mapped.message, contains('temporarily unavailable'));
      expect(mapped.message, isNot(contains('Verification unavailable')));
    });

    testWidgets('500 FUNDRAISING_REQUEST_FAILED shows as server issue', (
      tester,
    ) async {
      final error = ApiClientException(
        message: 'Server error',
        statusCode: 500,
        code: 'FUNDRAISING_REQUEST_FAILED',
      );

      final mapped = mapFundraisingSafeError(error);

      expect(mapped.isServerFailure, isTrue);
      expect(mapped.statusCode, 500);
      expect(mapped.backendCode, 'FUNDRAISING_REQUEST_FAILED');
      expect(mapped.message, isNotEmpty);
    });

    testWidgets('401 CENTRAL_TOKEN_EXPIRED shows session expired', (
      tester,
    ) async {
      final error = ApiClientException(
        message: 'JWT expired',
        statusCode: 401,
        code: 'CENTRAL_TOKEN_EXPIRED',
      );

      final mapped = mapFundraisingSafeError(error);

      expect(mapped.isSessionExpired, isTrue);
      expect(mapped.statusCode, 401);
      expect(mapped.message, contains('session'));
    });

    testWidgets('400 validation shows as validation error', (tester) async {
      final error = ApiClientException(
        message: 'Validation error',
        statusCode: 400,
        code: 'FUNDRAISING_VALIDATION_ERROR',
        responseData: {
          'details': [
            {'path': 'title', 'message': 'Title is required'},
          ],
        },
      );

      final mapped = mapFundraisingSafeError(error);

      expect(mapped.category, FundraisingErrorCategory.validation);
      expect(mapped.statusCode, 400);
    });

    testWidgets('Network error shows as network category', (tester) async {
      final error = ApiClientException(
        message: 'Connection refused',
        dioExceptionType: 'connectionError',
      );

      final mapped = mapFundraisingSafeError(error);

      expect(mapped.isNetwork, isTrue);
      expect(mapped.message, contains('Unable to connect'));
    });

    testWidgets('Timeout error shows as network category', (tester) async {
      final error = ApiClientException(
        message: 'Request timeout',
        dioExceptionType: 'receiveTimeout',
      );

      final mapped = mapFundraisingSafeError(error);

      expect(mapped.isNetwork, isTrue);
    });

    testWidgets('Backend code takes precedence over HTTP status', (
      tester,
    ) async {
      // 409 can be generic conflict, but with ACCOUNT_INCOMPLETE code
      // should map to accountIncomplete specifically
      final error = ApiClientException(
        message: 'Account incomplete',
        statusCode: 409,
        code: 'FUNDRAISING_ACCOUNT_INCOMPLETE',
        responseData: {
          'details': {
            'missingRequirements': ['presentAddress'],
          },
        },
      );

      final mapped = mapFundraisingSafeError(error);

      expect(mapped.isAccountIncomplete, isTrue);
      expect(mapped.category, isNot(FundraisingErrorCategory.validation));
    });

    testWidgets('Missing requirements null-safety: no details', (tester) async {
      final error = FundraisingSafeError(
        category: FundraisingErrorCategory.accountIncomplete,
        message: 'Incomplete',
      );

      expect(error.missingRequirements, isNull);
    });

    testWidgets('Missing requirements null-safety: empty details', (
      tester,
    ) async {
      final error = FundraisingSafeError(
        category: FundraisingErrorCategory.accountIncomplete,
        message: 'Incomplete',
        details: {},
      );

      expect(error.missingRequirements, isNull);
    });

    testWidgets('Missing requirements extraction from details', (tester) async {
      final error = FundraisingSafeError(
        category: FundraisingErrorCategory.accountIncomplete,
        message: 'Incomplete',
        details: {
          'missingRequirements': ['presentAddress', 'dateOfBirth', 'documents'],
        },
      );

      expect(error.missingRequirements, [
        'presentAddress',
        'dateOfBirth',
        'documents',
      ]);
    });
  });
}
