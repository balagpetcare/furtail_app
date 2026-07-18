import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/deep_link/deep_link_parser.dart';
import 'package:furtail_app/core/deep_link/deep_link_target.dart';

/// Verifies the reset-password deep link added in the final hardening pass:
/// the Central Auth reset email (routed per-client via
/// PASSWORD_RESET_URL_BY_CLIENT) deep-links into ResetPasswordScreen with the
/// opaque token extracted from the `token` query parameter.
void main() {
  group('DeepLinkParser reset-password', () {
    test('custom scheme furtail://reset-password?token=... resolves', () {
      final t = DeepLinkParser.parse(
        Uri.parse('furtail://reset-password?token=abc123'),
      );
      expect(t?.kind, DeepLinkKind.resetPassword);
      expect(t?.id, 'abc123');
    });

    test('underscore + hyphen aliases both resolve', () {
      expect(
        DeepLinkParser.parse(
          Uri.parse('furtail://reset_password?token=t1'),
        )?.kind,
        DeepLinkKind.resetPassword,
      );
    });

    test('https allowed-host reset link resolves', () {
      final t = DeepLinkParser.parse(
        Uri.parse('https://app.furtail.global/reset-password?token=xyz789'),
      );
      expect(t?.kind, DeepLinkKind.resetPassword);
      expect(t?.id, 'xyz789');
    });

    test('https reset link on a NON-allowed host is rejected (anti-spoof)', () {
      final t = DeepLinkParser.parse(
        Uri.parse('https://evil.example.com/reset-password?token=xyz789'),
      );
      expect(t, isNull);
    });

    test('missing token yields null (nothing to reset with)', () {
      final t = DeepLinkParser.parse(Uri.parse('furtail://reset-password'));
      expect(t, isNull);
    });

    test('parseString handles a full custom-scheme reset URL', () {
      final t = DeepLinkParser.parseString('furtail://reset-password?token=q');
      expect(t?.kind, DeepLinkKind.resetPassword);
      expect(t?.id, 'q');
    });
  });
}
