import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/otp_destination_masking.dart';

void main() {
  group('OtpDestinationMasking.maskEmail', () {
    test('masks the local part, keeps the domain', () {
      expect(
        OtpDestinationMasking.maskEmail('jane.doe@example.com'),
        'j***@example.com',
      );
    });

    test('single-character local part stays readable', () {
      expect(OtpDestinationMasking.maskEmail('a@b.com'), 'a@b.com');
    });

    test('no @ sign returns input unchanged', () {
      expect(OtpDestinationMasking.maskEmail('notanemail'), 'notanemail');
    });
  });

  group('OtpDestinationMasking.maskPhone', () {
    test('local BD format keeps 3-digit prefix and last 4 digits', () {
      expect(OtpDestinationMasking.maskPhone('01712345678'), '017***5678');
    });

    test('E.164 format keeps the + and country code prefix', () {
      expect(OtpDestinationMasking.maskPhone('+8801712345678'), '+880***5678');
    });

    test('very short numbers are returned unmasked', () {
      expect(OtpDestinationMasking.maskPhone('12345'), '12345');
    });
  });

  group('OtpDestinationMasking.mask', () {
    test('dispatches to email masking for the email channel', () {
      expect(
        OtpDestinationMasking.mask('email', 'jane.doe@example.com'),
        'j***@example.com',
      );
    });

    test('dispatches to phone masking for phone and whatsapp channels', () {
      expect(OtpDestinationMasking.mask('phone', '01712345678'), '017***5678');
      expect(
        OtpDestinationMasking.mask('whatsapp', '01712345678'),
        '017***5678',
      );
    });
  });
}
