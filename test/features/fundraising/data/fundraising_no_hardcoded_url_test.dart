import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against a regression where the fundraising feature grows its own
/// hardcoded LAN IP / raw Dio instance instead of going through the
/// canonical `ApiConfig`/`ApiClient`/`ApiEndpoints`.
void main() {
  group('Fundraising feature has no feature-level hardcoded API URL', () {
    final ipv4Pattern = RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b');

    final filesToCheck = <String>[
      'lib/features/fundraising/data/repositories/fundraising_repository.dart',
      'lib/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart',
      'lib/features/fundraising/presentation/providers/fundraising_providers.dart',
      'lib/features/fundraising/presentation/screens/fundraising_create_screen.dart',
      'lib/features/fundraising/presentation/screens/fundraising_account_setup_screen.dart',
      'lib/features/fundraising/presentation/screens/fundraising_account_documents_screen.dart',
    ];

    for (final relativePath in filesToCheck) {
      test('$relativePath has no raw IPv4 literal or raw Dio() instance', () {
        final file = File(relativePath);
        expect(file.existsSync(), isTrue, reason: '$relativePath must exist');
        final content = file.readAsStringSync();

        expect(
          ipv4Pattern.hasMatch(content),
          isFalse,
          reason:
              '$relativePath must not hardcode an IP address; it must resolve '
              'the API host via the canonical ApiConfig.',
        );
        expect(
          content.contains('Dio('),
          isFalse,
          reason:
              '$relativePath must go through the canonical ApiClient, not '
              'instantiate its own Dio().',
        );
        expect(
          content.contains("package:http/http.dart"),
          isFalse,
          reason: '$relativePath must not use package:http directly.',
        );
      });
    }
  });
}
