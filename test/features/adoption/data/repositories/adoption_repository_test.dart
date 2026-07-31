import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_form_payload.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_listing_form_payload.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/services/api_client.dart';

class _FakeRemote extends AdoptionRemoteDs {
  _FakeRemote()
    : super(ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'))));

  int? capturedAdoptionId;
  Map<String, dynamic>? capturedPayload;
  String? capturedStatus;
  bool submitForReviewCalled = false;
  bool deleteCalled = false;

  @override
  Future<Map<String, dynamic>> applyToAdopt(
    int adoptionId,
    Map<String, dynamic> payload,
  ) async {
    capturedAdoptionId = adoptionId;
    capturedPayload = payload;
    return {
      'id': 11,
      'status': 'SUBMITTED',
      'applicant': {
        'id': 1,
        'profile': {
          'displayName': 'Member One',
          'username': 'memberone',
          'avatarMedia': null,
        },
      },
      'pet': {
        'id': adoptionId,
        'name': 'Luna',
        'species': 'DOG',
        'breed': 'Mixed',
        'status': 'PUBLISHED',
      },
      'applicantName': 'Member One',
      'applicantPhone': '0123456789',
      'applicantCityAreaText': 'Dhaka',
      'applicantAddress': 'Dhaka',
      'messageToOwner': 'Please consider me',
      'answers': const [],
      'consentToHomeCheck': true,
      'consentToFollowUp': true,
      'createdAt': '2026-07-27T00:00:00.000Z',
    };
  }

  @override
  Future<Map<String, dynamic>> createAdoptionListing(
    Map<String, dynamic> payload,
  ) async {
    capturedPayload = payload;
    return {
      'id': 123,
      'name': 'Luna',
      'species': 'DOG',
      'breed': 'Mixed',
      'status': 'DRAFT',
    };
  }

  @override
  Future<Map<String, dynamic>> updateAdoptionListing(
    int id,
    Map<String, dynamic> payload,
  ) async {
    capturedAdoptionId = id;
    capturedPayload = payload;
    return {
      'id': id,
      'name': 'Luna',
      'species': 'DOG',
      'breed': 'Mixed',
      'status': 'DRAFT',
    };
  }

  @override
  Future<Map<String, dynamic>> submitAdoptionForReview(int id) async {
    submitForReviewCalled = true;
    return {
      'id': id,
      'name': 'Luna',
      'species': 'DOG',
      'breed': 'Mixed',
      'status': 'PUBLISHED',
    };
  }

  @override
  Future<Map<String, dynamic>> updateAdoptionListingStatus(
    int id,
    String status,
  ) async {
    capturedAdoptionId = id;
    capturedStatus = status;
    return {
      'id': id,
      'name': 'Luna',
      'species': 'DOG',
      'breed': 'Mixed',
      'status': status,
    };
  }

  @override
  Future<Map<String, dynamic>> deleteAdoptionListing(int id) async {
    capturedAdoptionId = id;
    deleteCalled = true;
    return {'id': id, 'success': true};
  }
}

void main() {
  test(
    'applyToAdopt forwards the form payload unchanged to the remote datasource',
    () async {
      final remote = _FakeRemote();
      final repository = AdoptionRepository(remote);
      final payload = AdoptionApplicationFormPayload(
        applicantName: 'Member One',
        applicantPhone: '0123456789',
        applicantWhatsappPhone: '',
        applicantLocationText: 'Dhaka',
        applicantCityAreaText: 'Dhaka',
        applicantEmail: '',
        housingType: 'Apartment',
        familyApproval: true,
        previousPetExperience: '2 years',
        currentPetsNote: '',
        incomeRange: '',
        canProvideVetCare: true,
        adoptionReason: 'Please consider me',
        ownerConditionAnswers: '',
        acceptsTerms: true,
      );

      await repository.applyToAdopt(42, payload);

      expect(remote.capturedAdoptionId, 42);
      expect(remote.capturedPayload, isNotNull);
      expect(remote.capturedPayload!['applicantName'], 'Member One');
      expect(remote.capturedPayload!['applicantPhone'], '0123456789');
      expect(remote.capturedPayload!['messageToOwner'], 'Please consider me');
    },
  );

  group('AdoptionRepository Lifecycle & Actions', () {
    test(
      'createAdoptionListing chains submitAdoptionForReview when submitNow is true',
      () async {
        final remote = _FakeRemote();
        final repository = AdoptionRepository(remote);
        final payload = AdoptionListingFormPayload(
          name: 'Luna',
          species: 'DOG',
          breed: 'Mixed',
          ageText: '2 years',
          gender: 'MALE',
          sizeText: 'MEDIUM',
          colorText: 'WHITE',
          description: 'Happy puppy',
          adoptionReason: 'Moving',
          countryId: 1,
          ownerContactPhone: '01700000000',
          ownerWhatsappPhone: '01700000000',
          ownerCityAreaText: 'Dhaka',
          pickupLocationNotes: 'Near park',
          allowInternationalAdoption: false,
          vaccinated: true,
          dewormed: true,
          neutered: false,
          microchipped: false,
          previousPetExperienceRequired: false,
          familyApprovalRequired: false,
          canProvideVetCare: false,
          noResaleAgreement: false,
          followUpAgreement: false,
          customServiceAreasText: '',
          serviceAreaType: 'CITY',
          serviceAreaNotes: '',
          healthInfo: 'Healthy',
          minimumIncomeRange: '',
          maximumIncomeRange: '',
          adopterConditionNote: '',
        );

        final result = await repository.createAdoptionListing(
          payload,
          submitNow: true,
        );

        expect(remote.capturedPayload, isNotNull);
        expect(remote.submitForReviewCalled, isTrue);
        expect(result.status, 'Published');
      },
    );

    test(
      'updateAdoptionListingStatus calls the status patch endpoint',
      () async {
        final remote = _FakeRemote();
        final repository = AdoptionRepository(remote);

        final result = await repository.updateAdoptionListingStatus(
          123,
          'PAUSED',
        );

        expect(remote.capturedAdoptionId, 123);
        expect(remote.capturedStatus, 'PAUSED');
        expect(result.status, 'Paused');
      },
    );

    test('hardDeleteListing invokes delete client call', () async {
      final remote = _FakeRemote();
      final repository = AdoptionRepository(remote);

      await repository.hardDeleteListing(456);

      expect(remote.capturedAdoptionId, 456);
      expect(remote.deleteCalled, isTrue);
    });
  });
}
