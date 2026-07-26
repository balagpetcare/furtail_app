import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/fundraising_error_mapper.dart';
import 'package:furtail_app/services/api_client.dart';

/// Regression coverage for the shared, code-first error presentation used by
/// the Create Fundraiser preflight, the Verification setup screen, and the
/// verification documents screen. A recognized domain error must never be
/// flattened into a generic "Verification unavailable" / "temporarily
/// unavailable" heading.
void main() {
  FundraisingSafeError map(
    int status,
    String code, {
    Map<String, dynamic>? responseData,
  }) {
    return mapFundraisingSafeError(
      ApiClientException(
        message: 'backend message',
        statusCode: status,
        code: code,
        responseData: responseData,
      ),
    );
  }

  group('fundraisingErrorTitle — verification screen mapping', () {
    test('409 FUNDRAISING_ACCOUNT_INCOMPLETE is not a generic unavailable', () {
      final title = fundraisingErrorTitle(
        map(409, 'FUNDRAISING_ACCOUNT_INCOMPLETE'),
      );
      expect(title, 'Complete your fundraising profile');
      expect(title, isNot(contains('unavailable')));
      expect(title, isNot('Verification unavailable'));
    });

    test('403 FUNDRAISING_FORBIDDEN reads as rejected, never under review', () {
      final title = fundraisingErrorTitle(map(403, 'FUNDRAISING_FORBIDDEN'));
      expect(title, 'Fundraising account rejected');
      expect(title.toLowerCase(), isNot(contains('under review')));
      expect(title, isNot('Verification unavailable'));
    });

    test('503 FUNDRAISING_SCHEMA_UNAVAILABLE is the temporary state', () {
      expect(
        fundraisingErrorTitle(map(503, 'FUNDRAISING_SCHEMA_UNAVAILABLE')),
        'Fundraising is temporarily unavailable',
      );
    });

    test('500 FUNDRAISING_REQUEST_FAILED is a server failure', () {
      final title = fundraisingErrorTitle(
        map(500, 'FUNDRAISING_REQUEST_FAILED'),
      );
      expect(title, 'We could not complete this request');
      expect(title, isNot('Verification unavailable'));
    });

    test('401 maps to session expired', () {
      expect(
        fundraisingErrorTitle(map(401, 'CENTRAL_TOKEN_EXPIRED')),
        'Session expired',
      );
    });

    test('no recognized domain error yields "Verification unavailable"', () {
      const codes = <int, String>{
        409: 'FUNDRAISING_ACCOUNT_INCOMPLETE',
        403: 'FUNDRAISING_FORBIDDEN',
        503: 'FUNDRAISING_SCHEMA_UNAVAILABLE',
        500: 'FUNDRAISING_REQUEST_FAILED',
        401: 'CENTRAL_TOKEN_EXPIRED',
        400: 'FUNDRAISING_VALIDATION_ERROR',
      };
      for (final entry in codes.entries) {
        expect(
          fundraisingErrorTitle(map(entry.key, entry.value)),
          isNot('Verification unavailable'),
          reason: '${entry.key} ${entry.value} must have a specific title',
        );
      }
    });
  });

  group('fundraisingErrorDescription — missing requirements', () {
    test('renders readable actions instead of raw backend keys', () {
      final description = fundraisingErrorDescription(
        map(
          409,
          'FUNDRAISING_ACCOUNT_INCOMPLETE',
          responseData: {
            'details': {
              'missingRequirements': ['presentAddress', 'documents'],
            },
          },
        ),
      );

      expect(description, contains('Complete your present address'));
      expect(description, contains('Upload a verification document'));
      expect(description, isNot(contains('presentAddress')));
      expect(description, isNot(contains('documents')));
    });

    test('falls back to the safe message when requirements are absent', () {
      final error = map(409, 'FUNDRAISING_ACCOUNT_INCOMPLETE');
      expect(fundraisingErrorDescription(error), error.message);
    });
  });

  group('formatFundraisingMissingRequirements', () {
    test('deduplicates the several location keys into one action', () {
      final formatted = formatFundraisingMissingRequirements(const [
        'divisionId',
        'districtId',
        'upazilaId',
        'unionId',
        'areaId',
      ]);

      expect(formatted, ['Add your location']);
      expect(formatted.length, 1);
    });

    test('drops unknown keys rather than leaking them raw', () {
      final formatted = formatFundraisingMissingRequirements(const [
        'presentAddress',
        'someInternalFlag',
      ]);

      expect(formatted, ['Complete your present address']);
    });

    test('keeps distinct requirements separate and ordered', () {
      final formatted = formatFundraisingMissingRequirements(const [
        'presentAddress',
        'dateOfBirth',
        'documents',
      ]);

      expect(formatted, [
        'Complete your present address',
        'Add your date of birth',
        'Upload a verification document',
      ]);
    });

    test('empty input yields no actions', () {
      expect(formatFundraisingMissingRequirements(const []), isEmpty);
    });
  });
}
