import 'package:furtail_app/core/deep_link/deep_link_parser.dart';
import 'package:furtail_app/core/deep_link/deep_link_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepLinkParser campaign routes', () {
    test('campaign/detail/slug opens detail', () {
      final t = DeepLinkParser.parseString('campaign/detail/cat-flu-2026');
      expect(t?.kind, DeepLinkKind.campaignDetail);
      expect(t?.id, 'cat-flu-2026');
    });

    test('campaign/slug slug route opens detail', () {
      final t = DeepLinkParser.parseString('campaign/uat-free-2026');
      expect(t?.kind, DeepLinkKind.campaignDetail);
      expect(t?.id, 'uat-free-2026');
    });

    test('campaign numeric id opens hub', () {
      final t = DeepLinkParser.parseString('campaign/42');
      expect(t?.kind, DeepLinkKind.campaign);
      expect(t?.id, '42');
    });

    test('furtail scheme campaign detail', () {
      final t = DeepLinkParser.parse(Uri.parse('furtail://campaign/detail/my-slug'));
      expect(t?.kind, DeepLinkKind.campaignDetail);
      expect(t?.id, 'my-slug');
    });
  });
}
