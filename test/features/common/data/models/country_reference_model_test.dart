import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/common/data/models/country_reference_model.dart';

void main() {
  group('CountryReferenceModel', () {
    test('parses reference data and identifies Bangladesh by iso2 only', () {
      final country = CountryReferenceModel.fromJson({
        'id': 1,
        'iso2': 'bd',
        'name': 'People\'s Republic of Bangladesh',
        'isDefault': true,
      });

      expect(country.id, 1);
      expect(country.iso2, 'bd');
      expect(country.isBangladesh, isTrue);
      expect(country.isDefault, isTrue);
    });
  });
}
