import 'package:flutter_test/flutter_test.dart';

import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';

FundraisingAccount _account(Map<String, dynamic> overrides) {
  final payload = <String, dynamic>{
    'id': 1,
    'status': 'PENDING',
    'documents': const <dynamic>[],
    ...overrides,
  };
  return FundraisingAccount.fromJson(payload);
}

Map<String, dynamic> _document({
  required int id,
  String documentType = 'SUPPORTING',
}) {
  return <String, dynamic>{
    'id': id,
    'title': 'Doc $id',
    'documentType': documentType,
    'media': <String, dynamic>{},
  };
}

const _bdComplete = <String, dynamic>{
  'fullName': 'Nadia Rahman',
  'dateOfBirth': '1998-05-14',
  'presentAddress': 'Village Road',
  'permanentAddress': 'Village Road',
  'divisionId': 1,
  'districtId': 2,
  'upazilaId': 3,
  'unionId': 4,
  'primaryDocumentType': 'NID',
  'nationalIdNumber': '1234567890',
};

void main() {
  group('FundraisingAccountReadiness.fromAccount — Bangladesh location', () {
    test(
      'treats a union with no areaId as a complete location (area optional)',
      () {
        final account = _account({
          ..._bdComplete,
          'areaId': null,
          'documents': [_document(id: 1, documentType: 'PRIMARY')],
        });

        final readiness = FundraisingAccountReadiness.fromAccount(account);

        expect(readiness.missingProfileFields, isNot(contains('location')));
        expect(readiness.canStartFundraiser, isTrue);
      },
    );

    test('reports missing location when upazila/union are not set', () {
      final account = _account({
        'fullName': 'Nadia Rahman',
        'dateOfBirth': '1998-05-14',
        'presentAddress': 'Village Road',
        'permanentAddress': 'Village Road',
        'divisionId': 1,
        'districtId': 2,
      });

      final readiness = FundraisingAccountReadiness.fromAccount(account);

      expect(readiness.missingProfileFields, contains('location'));
      expect(readiness.canStartFundraiser, isFalse);
    });
  });

  group('FundraisingAccountReadiness.fromAccount — international location', () {
    test('treats a complete international address as satisfying location', () {
      final account = _account({
        'fullName': 'Nadia Rahman',
        'dateOfBirth': '1998-05-14',
        'presentAddress': '123 Market St',
        'permanentAddress': '123 Market St',
        'isInternational': true,
        'countryCode': 'US',
        'countryName': 'United States',
        'stateName': 'California',
        'cityName': 'San Jose',
        'addressLine': '123 Market St',
        'primaryDocumentType': 'PASSPORT',
        'passportNumber': 'P1234567',
        'documents': [_document(id: 1, documentType: 'PRIMARY')],
      });

      final readiness = FundraisingAccountReadiness.fromAccount(account);

      expect(readiness.missingProfileFields, isNot(contains('location')));
      expect(readiness.canStartFundraiser, isTrue);
    });

    test(
      'does not accept Bangladesh ids as satisfying an international account',
      () {
        final account = _account({
          'isInternational': true,
          'divisionId': 1,
          'districtId': 2,
          'upazilaId': 3,
          'unionId': 4,
        });

        final readiness = FundraisingAccountReadiness.fromAccount(account);

        expect(readiness.missingProfileFields, contains('location'));
      },
    );
  });

  group('FundraisingAccountReadiness.fromAccount — date of birth', () {
    test('round-trips a date-only value without shifting the calendar day', () {
      final account = _account({'dateOfBirth': '2000-01-01'});

      expect(account.dateOfBirth, DateTime(2000, 1, 1));
    });

    test('reports dateOfBirth missing when absent', () {
      final account = _account(const {});

      final readiness = FundraisingAccountReadiness.fromAccount(account);

      expect(readiness.missingProfileFields, contains('dateOfBirth'));
    });
  });

  group('FundraisingAccountReadiness.fromAccount — full name', () {
    test('never falls back to an email-shaped value automatically', () {
      final account = _account(const {'fullName': null});

      final readiness = FundraisingAccountReadiness.fromAccount(account);

      expect(readiness.missingProfileFields, contains('fullName'));
      expect(account.fullName, isNull);
    });

    test('is satisfied once an explicit full name is present', () {
      final account = _account({..._bdComplete});

      final readiness = FundraisingAccountReadiness.fromAccount(account);

      expect(readiness.missingProfileFields, isNot(contains('fullName')));
    });
  });

  group(
    'FundraisingAccountReadiness.fromAccount — primary identity document',
    () {
      test('requires only the number for the selected primary type', () {
        final withoutNumber = _account({
          ..._bdComplete,
          'primaryDocumentType': 'PASSPORT',
          'nationalIdNumber': '1234567890',
          'passportNumber': null,
        });
        expect(
          FundraisingAccountReadiness.fromAccount(
            withoutNumber,
          ).missingProfileFields,
          contains('primaryDocumentNumber'),
        );

        final withNumber = _account({
          ..._bdComplete,
          'primaryDocumentType': 'PASSPORT',
          'passportNumber': 'P1234567',
        });
        expect(
          FundraisingAccountReadiness.fromAccount(
            withNumber,
          ).missingProfileFields,
          isNot(contains('primaryDocumentNumber')),
        );
      });

      test(
        'does not block on birth registration/passport/school ID unless selected as primary',
        () {
          final account = _account({
            ..._bdComplete,
            'primaryDocumentType': 'NID',
            'birthRegNumber': null,
            'passportNumber': null,
            'studentIdNumber': null,
          });

          final readiness = FundraisingAccountReadiness.fromAccount(account);

          expect(
            readiness.missingProfileFields,
            isNot(contains('primaryDocumentNumber')),
          );
        },
      );
    },
  );

  group('FundraisingAccountReadiness.fromAccount — documents', () {
    test('only a PRIMARY-tagged document satisfies the requirement', () {
      final withSupportingOnly = _account({
        ..._bdComplete,
        'documents': [_document(id: 1, documentType: 'SUPPORTING')],
      });
      expect(
        FundraisingAccountReadiness.fromAccount(
          withSupportingOnly,
        ).requiredDocumentsUploaded,
        isFalse,
      );

      final withPrimary = _account({
        ..._bdComplete,
        'documents': [
          _document(id: 1, documentType: 'SUPPORTING'),
          _document(id: 2, documentType: 'PRIMARY'),
        ],
      });
      final readiness = FundraisingAccountReadiness.fromAccount(withPrimary);
      expect(readiness.requiredDocumentsUploaded, isTrue);
      expect(readiness.canStartFundraiser, isTrue);
    });
  });
}
