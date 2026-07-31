import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_listing_form_payload.dart';

void main() {
  group('AdoptionListingFormPayload', () {
    test('serializes urban branch fields without rural IDs', () {
      final payload = AdoptionListingFormPayload(
        name: 'Momo',
        species: 'CAT',
        breed: 'Mixed',
        ageText: '2 years',
        gender: 'FEMALE',
        sizeText: 'Small',
        colorText: 'Black',
        description: 'Friendly cat',
        adoptionReason: 'Relocation',
        vaccinated: true,
        dewormed: false,
        neutered: false,
        microchipped: false,
        healthInfo: 'Healthy',
        ownerContactPhone: '01700000000',
        ownerWhatsappPhone: '',
        ownerCityAreaText: 'Dhaka',
        pickupLocationNotes: 'Call first',
        countryId: 1,
        bdDivisionId: 30,
        bdDistrictId: 3026,
        bdAddressMode: 'URBAN',
        bdCityCorporationId: 7001,
        bdZoneId: 7101,
        bdWardId: 7201,
        bdUpazilaId: null,
        bdUnionId: null,
        bdAreaId: 7301,
        serviceAreaType: 'SAME_CITY',
        allowInternationalAdoption: false,
        customServiceAreasText: '',
        serviceAreaNotes: '',
        previousPetExperienceRequired: false,
        familyApprovalRequired: false,
        canProvideVetCare: false,
        noResaleAgreement: false,
        followUpAgreement: false,
        minimumIncomeRange: '',
        maximumIncomeRange: '',
        adopterConditionNote: '',
      );

      final json = payload.toApiPayload(submitNow: false);

      expect(json['bdAddressMode'], 'URBAN');
      expect(json['bdCityCorporationId'], 7001);
      expect(json['bdZoneId'], 7101);
      expect(json['bdWardId'], 7201);
      expect(json['bdUpazilaId'], isNull);
      expect(json['bdUnionId'], isNull);
      expect(json['bdAreaId'], 7301);
    });

    test('serializes rural branch fields without urban IDs', () {
      final payload = AdoptionListingFormPayload(
        name: 'Momo',
        species: 'CAT',
        breed: 'Mixed',
        ageText: '2 years',
        gender: 'FEMALE',
        sizeText: 'Small',
        colorText: 'Black',
        description: 'Friendly cat',
        adoptionReason: 'Relocation',
        vaccinated: true,
        dewormed: false,
        neutered: false,
        microchipped: false,
        healthInfo: 'Healthy',
        ownerContactPhone: '01700000000',
        ownerWhatsappPhone: '',
        ownerCityAreaText: 'Dhaka',
        pickupLocationNotes: 'Call first',
        countryId: 1,
        bdDivisionId: 30,
        bdDistrictId: 3026,
        bdAddressMode: 'RURAL',
        bdCityCorporationId: null,
        bdZoneId: null,
        bdWardId: null,
        bdUpazilaId: 302601,
        bdUnionId: 5001,
        bdAreaId: 7303,
        serviceAreaType: 'SAME_DISTRICT',
        allowInternationalAdoption: false,
        customServiceAreasText: '',
        serviceAreaNotes: '',
        previousPetExperienceRequired: false,
        familyApprovalRequired: false,
        canProvideVetCare: false,
        noResaleAgreement: false,
        followUpAgreement: false,
        minimumIncomeRange: '',
        maximumIncomeRange: '',
        adopterConditionNote: '',
      );

      final json = payload.toApiPayload(submitNow: true);

      expect(json['bdAddressMode'], 'RURAL');
      expect(json['bdCityCorporationId'], isNull);
      expect(json['bdZoneId'], isNull);
      expect(json['bdWardId'], isNull);
      expect(json['bdUpazilaId'], 302601);
      expect(json['bdUnionId'], 5001);
      expect(json['bdAreaId'], 7303);
    });

    test('omits bdAreaId when no area is selected', () {
      final payload = AdoptionListingFormPayload(
        name: 'Momo',
        species: 'CAT',
        breed: 'Mixed',
        ageText: '2 years',
        gender: 'FEMALE',
        sizeText: 'Small',
        colorText: 'Black',
        description: 'Friendly cat',
        adoptionReason: 'Relocation',
        vaccinated: true,
        dewormed: false,
        neutered: false,
        microchipped: false,
        healthInfo: 'Healthy',
        ownerContactPhone: '01700000000',
        ownerWhatsappPhone: '',
        ownerCityAreaText: 'Dhaka',
        pickupLocationNotes: 'Call first',
        countryId: 1,
        bdDivisionId: 30,
        bdDistrictId: 3026,
        bdAddressMode: 'RURAL',
        bdCityCorporationId: null,
        bdZoneId: null,
        bdWardId: null,
        bdUpazilaId: 302601,
        bdUnionId: 5001,
        bdAreaId: null,
        serviceAreaType: 'SAME_DISTRICT',
        allowInternationalAdoption: false,
        customServiceAreasText: '',
        serviceAreaNotes: '',
        previousPetExperienceRequired: false,
        familyApprovalRequired: false,
        canProvideVetCare: false,
        noResaleAgreement: false,
        followUpAgreement: false,
        minimumIncomeRange: '',
        maximumIncomeRange: '',
        adopterConditionNote: '',
      );

      final json = payload.toApiPayload(submitNow: false);

      expect(json.containsKey('bdAreaId'), isFalse);
    });
  });
}
