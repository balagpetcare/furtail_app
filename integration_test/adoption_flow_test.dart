import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:furtail_app/core/config/app_config.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_listing_form_payload.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/common/data/repositories/animal_taxonomy_repository.dart';
import 'package:furtail_app/features/common/data/repositories/bd_locations_repository.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/services/api_client.dart';

import 'e2e_test_harness.dart';

Future<E2eTestHarness> _bootHarness(WidgetTester tester) async {
  await waitForApiReady();
  final harness = await E2eTestHarness.install(
    subject: '1',
    email: 'amina@example.com',
    displayName: 'Amina',
  );
  await launchAuthenticatedApp(tester, harness.session);
  return harness;
}

Map<String, dynamic> _mapOf(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

Future<
  ({
    BdDivision division,
    BdDistrict district,
    BdUpazila upazila,
    BdArea ruralArea,
    BdArea urbanArea,
  })
>
_resolveConnectedLocationPath(BdLocationsRepository locations) async {
  final divisions = await locations.getDivisions();
  for (final division in divisions) {
    if (division.id != 6) continue;
    final districts = await locations.getDistricts(divisionId: division.id);
    for (final district in districts) {
      if (district.id != 47) continue;
      final upazilas = await locations.getUpazilas(districtId: district.id);
      final cityCorporations = await locations.getCityCorporations(
        districtId: district.id,
      );
      if (upazilas.isEmpty || cityCorporations.isEmpty) continue;
      final upazila = upazilas.first;
      final ruralAreas = await locations.getAreas(upazilaId: upazila.id);
      if (ruralAreas.isEmpty) continue;
      final cityCorporation = cityCorporations.first;
      final zones = await locations.getZones(
        cityCorporationId: cityCorporation.id,
      );
      if (zones.isEmpty) continue;
      final zone = zones.first;
      final urbanAreas = await locations.getCcAreas(zoneId: zone.id);
      if (urbanAreas.isEmpty) continue;
      return (
        division: division,
        district: district,
        upazila: upazila,
        ruralArea: ruralAreas.first,
        urbanArea: urbanAreas.first,
      );
    }
  }
  for (final division in divisions) {
    final districts = await locations.getDistricts(divisionId: division.id);
    if (districts.isEmpty) continue;
    for (final district in districts) {
      final upazilas = await locations.getUpazilas(districtId: district.id);
      final cityCorporations = await locations.getCityCorporations(
        districtId: district.id,
      );
      if (upazilas.isEmpty || cityCorporations.isEmpty) continue;
      final upazila = upazilas.first;
      final ruralAreas = await locations.getAreas(upazilaId: upazila.id);
      if (ruralAreas.isEmpty) continue;
      final cityCorporation = cityCorporations.first;
      final zones = await locations.getZones(
        cityCorporationId: cityCorporation.id,
      );
      if (zones.isEmpty) continue;
      final zone = zones.first;
      final urbanAreas = await locations.getCcAreas(zoneId: zone.id);
      if (urbanAreas.isEmpty) continue;
      return (
        division: division,
        district: district,
        upazila: upazila,
        ruralArea: ruralAreas.first,
        urbanArea: urbanAreas.first,
      );
    }
  }
  throw StateError(
    'Unable to find a connected adoption location path with both rural and urban coverage.',
  );
}

Future<String> _makeInvalidUploadFixture() async {
  final dir = await Directory.systemTemp.createTemp('furtail-e2e-invalid-');
  final path = '${dir.path}${Platform.pathSeparator}broken.exe';
  await File(path).writeAsBytes(utf8.encode('invalid'));
  return path;
}

AdoptionListingFormPayload _payload({
  required String name,
  required String species,
  required String breed,
  required int animalTypeId,
  required int breedId,
  required int countryId,
  required int? bdDivisionId,
  required int? bdDistrictId,
  required int? bdUpazilaId,
  required int? bdAreaId,
  required String serviceAreaType,
  required List<int> mediaIds,
  String ownerCityAreaText = 'Dhaka',
  String pickupLocationNotes = 'Manual continuation after GPS failure.',
  String locationNotes = 'Manual location',
}) {
  return AdoptionListingFormPayload(
    name: name,
    species: species,
    breed: breed,
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
    ownerCityAreaText: ownerCityAreaText,
    pickupLocationNotes: pickupLocationNotes,
    countryId: countryId,
    bdDivisionId: bdDivisionId,
    bdDistrictId: bdDistrictId,
    bdUpazilaId: bdUpazilaId,
    bdAreaId: bdAreaId,
    serviceAreaType: serviceAreaType,
    allowInternationalAdoption: false,
    customServiceAreasText: locationNotes,
    serviceAreaNotes: locationNotes,
    previousPetExperienceRequired: true,
    familyApprovalRequired: true,
    canProvideVetCare: true,
    noResaleAgreement: true,
    followUpAgreement: true,
    minimumIncomeRange: '20000-50000',
    maximumIncomeRange: '50000-100000',
    adopterConditionNote: 'Must maintain regular vet care.',
    latitude: null,
    longitude: null,
    mediaIds: mediaIds,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'adoption flow creates one draft, covers rural and urban locations, uploads media, publishes, protects non-owner edits, and supports status/share',
    (tester) async {
      final harness = await _bootHarness(tester);
      final runId = uniqueDataSuffix();
      int? createdId;
      try {
        final api = ApiClient();
        final remote = AdoptionRemoteDs(api);
        final adoption = AdoptionRepository(remote);
        final locations = BdLocationsRepository(ApiClient());
        final taxonomy = AnimalTaxonomyRepository(ApiClient());

        final country = await adoption.fetchBangladeshCountry();
        expect(country.isBangladesh, isTrue);

        final locationPath = await _resolveConnectedLocationPath(locations);
        final division = locationPath.division;
        final district = locationPath.district;
        final upazila = locationPath.upazila;
        final ruralArea = locationPath.ruralArea;
        final urbanArea = locationPath.urbanArea;

        final animalTypes = await taxonomy.getAnimalTypes();
        expect(animalTypes, isNotEmpty);
        final animalType = animalTypes.first;
        final breeds = await taxonomy.getBreeds(animalTypeId: animalType.id);
        expect(breeds, isNotEmpty);
        final breed = breeds.first;

        final invalidPath = await _makeInvalidUploadFixture();
        try {
          await api.multipartPostTyped<Map<String, dynamic>>(
            url: '${AppConfig.apiV1}/media/upload',
            files: [
              ApiMultipartFilePart(
                fieldName: 'file',
                file: File(invalidPath),
                filename: 'broken.exe',
                contentType: null,
              ),
            ],
            fields: const <String, String>{
              'contentType': 'adoption',
              'contentId': 'adoption-invalid',
              'idempotencyKey': 'adoption-invalid',
            },
            parse: (decoded) => _mapOf(decoded)['data'] as Map<String, dynamic>,
          );
          fail('Expected an invalid upload to fail.');
        } on ApiClientException catch (error) {
          expect(error.statusCode, 415);
        }

        final imageUpload = await api.multipartPostTyped<Map<String, dynamic>>(
          url: '${AppConfig.apiV1}/media/upload',
          files: [
            ApiMultipartFilePart(
              fieldName: 'file',
              file: File(harness.artifacts.imagePath),
            ),
          ],
          fields: <String, String>{
            'contentType': 'adoption',
            'contentId': 'adoption-media-$runId',
            'idempotencyKey': 'adoption-image-1-$runId',
          },
          parse: (decoded) => _mapOf(decoded)['data'] as Map<String, dynamic>,
        );
        final duplicateImage = await api
            .multipartPostTyped<Map<String, dynamic>>(
              url: '${AppConfig.apiV1}/media/upload',
              files: [
                ApiMultipartFilePart(
                  fieldName: 'file',
                  file: File(harness.artifacts.imagePath),
                ),
              ],
              fields: <String, String>{
                'contentType': 'adoption',
                'contentId': 'adoption-media-$runId',
                'idempotencyKey': 'adoption-image-1-$runId',
              },
              parse: (decoded) =>
                  _mapOf(decoded)['data'] as Map<String, dynamic>,
            );
        expect(
          (duplicateImage['id'] as num).toInt(),
          (imageUpload['id'] as num).toInt(),
        );

        final videoUpload = await api.multipartPostTyped<Map<String, dynamic>>(
          url: '${AppConfig.apiV1}/media/upload',
          files: [
            ApiMultipartFilePart(
              fieldName: 'file',
              file: File(harness.artifacts.videoPath),
            ),
          ],
          fields: <String, String>{
            'contentType': 'adoption',
            'contentId': 'adoption-media-$runId',
            'idempotencyKey': 'adoption-video-1-$runId',
          },
          parse: (decoded) => _mapOf(decoded)['data'] as Map<String, dynamic>,
        );

        final beforeCount = (await adoption.fetchMyAdoptionListings()).length;
        final ruralDraft = _payload(
          name: 'E2E ${uniqueDataSuffix('adoption')}',
          species: animalType.code ?? animalType.name,
          breed: breed.name,
          animalTypeId: animalType.id,
          breedId: breed.id,
          countryId: country.id,
          bdDivisionId: division.id,
          bdDistrictId: district.id,
          bdUpazilaId: upazila.id,
          bdAreaId: ruralArea.id,
          serviceAreaType: 'SAME_DISTRICT',
          mediaIds: [
            (imageUpload['id'] as num).toInt(),
            (videoUpload['id'] as num).toInt(),
          ],
        );

        final created = await adoption.createAdoptionListing(
          ruralDraft,
          submitNow: false,
        );
        createdId = created.id;
        expect(created.status.toUpperCase(), 'DRAFT');
        expect(
          (await adoption.fetchMyAdoptionListings()).length,
          beforeCount + 1,
        );

        final restored = await adoption.fetchAdoptionDetail(created.id);
        expect(restored.id, created.id);

        final urbanDraft = _payload(
          name: created.name,
          species: ruralDraft.species,
          breed: ruralDraft.breed,
          animalTypeId: animalType.id,
          breedId: breed.id,
          countryId: country.id,
          bdDivisionId: division.id,
          bdDistrictId: district.id,
          bdUpazilaId: null,
          bdAreaId: urbanArea.id,
          serviceAreaType: 'SAME_CITY',
          mediaIds: ruralDraft.mediaIds,
          ownerCityAreaText: 'Urban branch',
          pickupLocationNotes: 'Urban branch',
          locationNotes: 'Urban branch',
        );

        final updated = await adoption.updateAdoptionListing(
          created.id,
          urbanDraft,
          submitNow: false,
        );
        expect(updated.bdAreaId, urbanArea.id);

        final published = _mapOf(
          await api.post(
            '${AppConfig.apiV1}/adoptions/${created.id}/publish',
            const <String, dynamic>{},
          ),
        );
        expect((published['data'] as Map)['status'], 'PUBLISHED');

        final detail = await adoption.fetchAdoptionDetail(created.id);
        expect(detail.status.toUpperCase(), anyOf('PUBLISHED', 'ADOPTED'));

        final ownerListing = await adoption.fetchAdoptionDetail(created.id);
        expect(ownerListing.viewerIsOwner, isTrue);

        final ownerSession = harness.session;
        final nonOwner = E2eTestSession(
          subject: '2',
          email: 'zara@example.com',
          displayName: 'Zara',
        );
        nonOwner.seed();
        try {
          final foreignView = await AdoptionRepository(
            AdoptionRemoteDs(ApiClient()),
          ).fetchAdoptionDetail(created.id);
          expect(foreignView.viewerIsOwner, isFalse);

          try {
            await AdoptionRepository(
              AdoptionRemoteDs(ApiClient()),
            ).updateAdoptionListing(created.id, urbanDraft, submitNow: false);
            fail('Expected non-owner edit to be denied.');
          } on ApiClientException catch (error) {
            expect(error.statusCode, 403);
          }
        } finally {
          ownerSession.seed();
        }

        final adopted = _mapOf(
          await api.patch(
            '${AppConfig.apiV1}/adoptions/${created.id}/status',
            <String, dynamic>{'status': 'ADOPTED'},
          ),
        );
        expect((adopted['data'] as Map)['status'], 'ADOPTED');

        final archived = _mapOf(
          await api.patch(
            '${AppConfig.apiV1}/adoptions/${created.id}/status',
            <String, dynamic>{'status': 'DELETED'},
          ),
        );
        expect((archived['data'] as Map)['status'], 'DELETED');
      } finally {
        if (createdId != null) {
          try {
            await ApiClient().delete('${AppConfig.apiV1}/adoptions/$createdId');
          } catch (_) {
            // Best-effort cleanup
          }
        }
        await harness.dispose();
      }
    },
  );
}
