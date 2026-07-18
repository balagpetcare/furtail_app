import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';

void main() {
  group('CentralAuthBootstrap.passwordPolicy', () {
    test('parses passwordPolicy when the backend sends it', () {
      final bootstrap = CentralAuthBootstrap.fromJson({
        'registrationOpen': true,
        'loginMethods': {},
        'passwordPolicy': {
          'minLength': 10,
          'requiresUppercase': true,
          'requiresNumber': true,
          'requiresSymbol': false,
        },
      });
      expect(bootstrap.passwordPolicy, isNotNull);
      expect(bootstrap.passwordPolicy!.minLength, 10);
      expect(bootstrap.passwordPolicy!.requiresUppercase, isTrue);
      expect(bootstrap.passwordPolicy!.requiresSymbol, isFalse);
    });

    test('is null when the backend omits passwordPolicy (no fabrication)', () {
      final bootstrap = CentralAuthBootstrap.fromJson({
        'registrationOpen': true,
        'loginMethods': {},
      });
      expect(bootstrap.passwordPolicy, isNull);
    });
  });

  group('CentralAuthPasswordPolicy.violations', () {
    const policy = CentralAuthPasswordPolicy(
      minLength: 8,
      requiresUppercase: true,
      requiresNumber: true,
      requiresSymbol: true,
    );

    test('flags every missing requirement', () {
      expect(
        policy.violations('short'),
        containsAll(['minLength', 'uppercase', 'number', 'symbol']),
      );
    });

    test('passes a compliant password', () {
      expect(policy.violations('Abcdef1!'), isEmpty);
    });

    test('flags only what is missing', () {
      expect(policy.violations('abcdefgh1!'), ['uppercase']);
    });
  });
}
