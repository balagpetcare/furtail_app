import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/network/api_config.dart';
import 'package:furtail_app/core/network/api_endpoints.dart';

void main() {
  group('ApiConfig / fundraising eligibility endpoint resolution', () {
    test('apiV1 appends /api/v1 to host exactly once', () {
      final apiV1 = ApiConfig.apiV1;
      expect(apiV1, '${ApiConfig.host}/api/v1');
      expect('/api/v1'.allMatches(apiV1).length, 1);
    });

    test('resolved base URL has no double slashes after the scheme', () {
      final apiV1 = ApiConfig.apiV1;
      final afterScheme = apiV1.replaceFirst('://', '');
      expect(afterScheme, isNot(contains('//')));
    });

    test(
      'fundraisingAccountMe() matches the canonical /api/v1/fundraising/account/me route',
      () {
        final url = ApiEndpoints.fundraisingAccountMe();
        expect(url, '${ApiConfig.apiV1}/fundraising/account/me');
        expect(url, endsWith('/api/v1/fundraising/account/me'));
        // Built entirely from the canonical ApiConfig — no separate
        // feature-level base URL for fundraising.
        expect(url, startsWith(ApiConfig.host));
      },
    );

    test(
      'fundraising endpoint uses no double slashes anywhere after the scheme',
      () {
        final url = ApiEndpoints.fundraisingAccountMe();
        final afterScheme = url.replaceFirst('://', '');
        expect(afterScheme, isNot(contains('//')));
      },
    );
  });
}
