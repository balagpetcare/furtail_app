import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/config/app_config.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_listing_form_payload.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_home_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/create_adoption_listing_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/my_adoption_listings_screen.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/common/data/repositories/animal_taxonomy_repository.dart';
import 'package:furtail_app/features/common/data/repositories/bd_locations_repository.dart';
import 'package:furtail_app/services/api_client.dart';

import 'e2e_test_harness.dart';

Future<
  ({
    BdDivision division,
    BdDistrict district,
    BdArea cityCorporation,
    BdArea zone,
    BdArea ward,
    BdArea? area,
  })
>
_resolveDhakaCityCorporationPath(BdLocationsRepository locations) async {
  final divisions = await locations.getDivisions();
  final division = divisions.firstWhere(
    (item) => item.nameEn == 'Dhaka' || item.code == 'DIV-DHAKA',
  );
  final districts = await locations.getDistricts(divisionId: division.id);
  final district = districts.firstWhere(
    (item) => item.nameEn == 'Dhaka' || item.code == 'DIS-DHAKA',
  );
  final corporations = await locations.getCityCorporations(
    districtId: district.id,
  );
  final cityCorporation = corporations.firstWhere(
    (item) =>
        item.code == 'CC-DNCC' ||
        item.nameEn == 'Dhaka North City Corporation' ||
        item.nameEn == 'Dhaka South City Corporation',
  );
  final zones = await locations.getZones(cityCorporationId: cityCorporation.id);
  final zone = zones.first;
  final wards = await locations.getWards(zoneId: zone.id);
  final ward = wards.first;
  final areas = await locations.getAreasByWard(wardId: ward.id);
  final area = areas.isEmpty ? null : areas.first;
  return (
    division: division,
    district: district,
    cityCorporation: cityCorporation,
    zone: zone,
    ward: ward,
    area: area,
  );
}

Future<String> _makeUniquePngFixture(String runId) async {
  final dir = await Directory.systemTemp.createTemp('furtail-city-corp-');
  final path = '${dir.path}${Platform.pathSeparator}city-corp-$runId.png';
  final image = img.Image(width: 8, height: 8);
  final seed = runId.hashCode;
  img.fill(
    image,
    color: img.ColorRgb8(seed & 0xFF, (seed >> 8) & 0xFF, (seed >> 16) & 0xFF),
  );
  await File(path).writeAsBytes(img.encodePng(image));
  return path;
}

AdoptionListingFormPayload _payload({
  required String name,
  required int countryId,
  required int animalTypeId,
  required int breedId,
  required int bdDivisionId,
  required int bdDistrictId,
  required int bdCityCorporationId,
  required int bdZoneId,
  required int bdWardId,
  required int? bdAreaId,
  required List<int> mediaIds,
}) {
  return AdoptionListingFormPayload(
    name: name,
    species: 'DOG',
    breed: 'Test Breed',
    animalTypeId: animalTypeId,
    breedId: breedId,
    ageText: '2 years',
    ageYears: 2,
    ageMonths: 0,
    ageDays: 0,
    totalAgeDays: 730,
    approximateDateOfBirth: '2024-01-01T00:00:00.000Z',
    gender: 'FEMALE',
    sizeText: 'Medium',
    colorText: 'Brown',
    description: 'Friendly companion for a stable home.',
    adoptionReason: 'The current caretaker can no longer keep this pet.',
    vaccinated: true,
    dewormed: true,
    neutered: false,
    microchipped: false,
    healthInfo: 'Healthy and active.',
    ownerContactPhone: '01700000000',
    ownerWhatsappPhone: '01700000000',
    ownerCityAreaText: 'Dhaka city corporation',
    pickupLocationNotes: 'By appointment only.',
    countryId: countryId,
    bdDivisionId: bdDivisionId,
    bdDistrictId: bdDistrictId,
    bdAddressMode: 'URBAN',
    bdCityCorporationId: bdCityCorporationId,
    bdZoneId: bdZoneId,
    bdWardId: bdWardId,
    bdUpazilaId: null,
    bdUnionId: null,
    bdAreaId: bdAreaId,
    serviceAreaType: 'SAME_CITY',
    allowInternationalAdoption: false,
    customServiceAreasText: 'Dhaka',
    serviceAreaNotes: 'Dhaka',
    previousPetExperienceRequired: true,
    familyApprovalRequired: true,
    canProvideVetCare: true,
    noResaleAgreement: true,
    followUpAgreement: true,
    minimumIncomeRange: '20000-50000',
    maximumIncomeRange: '50000-100000',
    adopterConditionNote: 'Must maintain regular vet care.',
    mediaIds: mediaIds,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('city corporation listing renders in my listings and public feed', (
    tester,
  ) async {
    final harness = await E2eTestHarness.install(
      subject: '101',
      email: 'dhaka.city@example.com',
      displayName: 'Dhaka City Owner',
    );
    final api = ApiClient();
    final adoption = AdoptionRepository(AdoptionRemoteDs(api));
    final locations = BdLocationsRepository(api);
    final taxonomy = AnimalTaxonomyRepository(api);
    final runId = uniqueDataSuffix('cc');
    AdoptionPetUiModel? created;

    try {
      final country = await adoption.fetchBangladeshCountry();
      final path = await _resolveDhakaCityCorporationPath(locations);
      final animalTypes = await taxonomy.getAnimalTypes();
      final animalType = animalTypes.first;
      final breeds = await taxonomy.getBreeds(animalTypeId: animalType.id);
      final breed = breeds.first;

      debugPrint(
        'CITY_PROOF path division=${path.division.id}:${path.division.display()} '
        'district=${path.district.id}:${path.district.display()} '
        'cc=${path.cityCorporation.id}:${path.cityCorporation.display()} '
        'zone=${path.zone.id}:${path.zone.display()} '
        'ward=${path.ward.id}:${path.ward.display()} '
        'area=${path.area?.id}:${path.area?.display() ?? 'none'}',
      );

      final uploadFixturePath = await _makeUniquePngFixture(runId);
      final upload = await api.multipartPostTyped<Map<String, dynamic>>(
        url: '${AppConfig.apiV1}/media/upload',
        files: [
          ApiMultipartFilePart(
            fieldName: 'file',
            file: File(uploadFixturePath),
          ),
        ],
        fields: <String, String>{
          'contentType': 'ADOPTION',
          'contentId': 'city-corp-$runId',
          'idempotencyKey': 'city-corp-image-$runId',
        },
        parse: (decoded) => Map<String, dynamic>.from(decoded['data'] as Map),
      );
      final mediaId = (upload['id'] as num).toInt();
      final mediaUrl = upload['url']?.toString() ?? '';

      created = await adoption.createAdoptionListing(
        _payload(
          name: 'Dhaka City Corp $runId',
          countryId: country.id,
          animalTypeId: animalType.id,
          breedId: breed.id,
          bdDivisionId: path.division.id,
          bdDistrictId: path.district.id,
          bdCityCorporationId: path.cityCorporation.id,
          bdZoneId: path.zone.id,
          bdWardId: path.ward.id,
          bdAreaId: path.area?.id,
          mediaIds: [mediaId],
        ),
        submitNow: true,
      );

      final detail = await adoption.fetchAdoptionDetail(created.id);
      debugPrint(
        'CITY_PROOF listing=${detail.id} status=${detail.status} '
        'division=${detail.bdDivisionId} district=${detail.bdDistrictId} '
        'cc=${detail.bdCityCorporationId} zone=${detail.bdZoneId} '
        'ward=${detail.bdWardId} area=${detail.bdAreaId} media=${detail.media.map((m) => m.id).toList()} '
        'cover=${detail.coverImageUrl}',
      );
      expect(detail.bdDivisionId, path.division.id);
      expect(detail.bdDistrictId, path.district.id);
      expect(detail.bdCityCorporationId, path.cityCorporation.id);
      expect(detail.bdZoneId, path.zone.id);
      expect(detail.bdWardId, path.ward.id);
      if (path.area != null) {
        expect(detail.bdAreaId, path.area!.id);
      }
      expect(detail.media, isNotEmpty);
      expect(mediaUrl, isNotEmpty);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MyAdoptionListingsScreen())),
      );
      await settleUntil(
        tester,
        finder: find.text('Dhaka City Corp $runId'),
        description: 'created city-corporation listing in My Adoption Listings',
      );
      expect(find.byType(FurtailCachedImage), findsWidgets);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdoptionHomeScreen())),
      );
      await settleUntil(
        tester,
        finder: find.text('Dhaka City Corp $runId'),
        description: 'created city-corporation listing in public adoption feed',
      );
      expect(find.byType(FurtailCachedImage), findsWidgets);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateAdoptionListingScreen(existingListing: created),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i += 1) {
        await tester.tap(find.text('Next').first);
        await tester.pumpAndSettle();
      }
      await settleUntil(
        tester,
        finder: find.text(path.cityCorporation.display()),
        description: 'restored city-corporation selection in edit mode',
      );
      expect(find.text(path.zone.display()), findsWidgets);
      expect(find.text(path.ward.display()), findsWidgets);
      if (path.area != null) {
        expect(find.text(path.area!.display()), findsWidgets);
      }

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CreateAdoptionListingScreen())),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('At least one photo or video is recommended.'),
        findsOneWidget,
      );
      expect(find.text('fixture.png'), findsNothing);
    } finally {
      if (created != null) {
        try {
          await api.delete('${AppConfig.apiV1}/adoptions/${created.id}');
        } catch (_) {
          // Best-effort cleanup.
        }
      }
      await harness.dispose();
    }
  });
}
