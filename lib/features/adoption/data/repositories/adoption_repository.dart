import 'package:furtail_app/dtos/pets/animal_type_dto.dart';
import 'package:furtail_app/dtos/pets/breed_dto.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_comment_model.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_form_payload.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_application_ui_model.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_listing_form_payload.dart';
import 'package:furtail_app/features/adoption/data/models/adoption_pet_ui_model.dart';
import 'package:furtail_app/features/legacy/data/models/country_model.dart';

class AdoptionRepository {
  final AdoptionRemoteDs _remote;

  AdoptionRepository(this._remote);

  Future<List<AdoptionPetUiModel>> fetchAdoptions({
    String? species,
    String? search,
    String? breed,
    String? gender,
    String? size,
    int? minAgeDays,
    int? maxAgeDays,
    bool? vaccinated,
    bool? dewormed,
    bool? neutered,
    bool? goodWithKids,
    bool? goodWithDogs,
    bool? goodWithCats,
    int? countryId,
    int? divisionId,
    int? stateId,
    int? districtId,
    int? cityId,
    int? areaId,
    double? nearLat,
    double? nearLng,
    int? radiusKm,
    int page = 1,
    int limit = 20,
  }) async {
    final items = await _remote.fetchAdoptions(
      species: species,
      search: search,
      breed: breed,
      gender: gender,
      size: size,
      minAgeDays: minAgeDays,
      maxAgeDays: maxAgeDays,
      vaccinated: vaccinated,
      dewormed: dewormed,
      neutered: neutered,
      goodWithKids: goodWithKids,
      goodWithDogs: goodWithDogs,
      goodWithCats: goodWithCats,
      countryId: countryId,
      divisionId: divisionId,
      stateId: stateId,
      districtId: districtId,
      cityId: cityId,
      areaId: areaId,
      nearLat: nearLat,
      nearLng: nearLng,
      radiusKm: radiusKm,
      page: page,
      limit: limit,
    );
    return items.map(AdoptionPetUiModel.fromApiJson).toList();
  }


  Future<AdoptionPetUiModel> fetchAdoptionDetail(int id) async {
    final item = await _remote.fetchAdoptionDetail(id);
    return AdoptionPetUiModel.fromApiJson(item);
  }

  Future<AdoptionPetUiModel> favoriteAdoption(int id) async {
    final item = await _remote.favoriteAdoption(id);
    return AdoptionPetUiModel.fromApiJson(item);
  }

  Future<AdoptionPetUiModel> unfavoriteAdoption(int id) async {
    final item = await _remote.unfavoriteAdoption(id);
    return AdoptionPetUiModel.fromApiJson(item);
  }

  Future<Map<String, dynamic>> fetchAdoptionComments(
    int id, {
    int limit = 50,
  }) async {
    return _remote.listAdoptionComments(id, limit: limit);
  }

  Future<AdoptionCommentModel> addAdoptionComment(
    int id,
    String text,
  ) async {
    final response = await _remote.addAdoptionComment(id, text);
    return AdoptionCommentModel.fromJson(
      (response['comment'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<Map<String, dynamic>> deleteAdoptionComment(
    int id,
    int commentId,
  ) {
    return _remote.deleteAdoptionComment(id, commentId);
  }

  Future<AdoptionPetUiModel> createAdoptionListing(
    AdoptionListingFormPayload payload, {
    required bool submitNow,
  }) async {
    final item = await _remote.createAdoptionListing(
      payload.toApiPayload(submitNow: submitNow),
    );
    return AdoptionPetUiModel.fromApiJson(item);
  }

  Future<AdoptionPetUiModel> updateAdoptionListing(
    int id,
    AdoptionListingFormPayload payload, {
    required bool submitNow,
  }) async {
    final item = await _remote.updateAdoptionListing(
      id,
      payload.toApiPayload(submitNow: submitNow),
    );
    return AdoptionPetUiModel.fromApiJson(item);
  }

  Future<AdoptionPetUiModel> submitAdoptionForReview(int id) async {
    final item = await _remote.submitAdoptionForReview(id);
    return AdoptionPetUiModel.fromApiJson(item);
  }

  Future<Country> fetchBangladeshCountry() {
    return _remote.fetchBangladeshCountry();
  }

  Future<Map<String, dynamic>> applyToAdopt(
    int adoptionId,
    AdoptionApplicationFormPayload payload,
  ) {
    return _remote.applyToAdopt(adoptionId, payload.toApiPayload());
  }

  Future<List<AdoptionPetUiModel>> fetchMyAdoptionListings() async {
    final items = await _remote.fetchMyAdoptionListings();
    return items.map(AdoptionPetUiModel.fromApiJson).toList();
  }

  Future<List<AdoptionApplicationUiModel>> fetchMyAdoptionApplications() async {
    final items = await _remote.fetchMyAdoptionApplications();
    return items.map(AdoptionApplicationUiModel.fromApiJson).toList();
  }

  Future<List<AdoptionApplicationUiModel>> fetchApplicationsForMyListing(
    int adoptionId, {
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final items = await _remote.fetchApplicationsForMyListing(
      adoptionId,
      status: status,
      page: page,
      limit: limit,
    );
    return items.map(AdoptionApplicationUiModel.fromApiJson).toList();
  }

  Future<AdoptionApplicationUiModel> fetchAdoptionApplicationDetail(
    int applicationId,
  ) async {
    final item = await _remote.fetchAdoptionApplicationDetail(applicationId);
    return AdoptionApplicationUiModel.fromApiJson(item);
  }

  Future<AdoptionApplicationUiModel> updateAdoptionApplicationStatus(
    int applicationId,
    String status, {
    String? note,
  }) async {
    final item = await _remote.updateAdoptionApplicationStatus(
      applicationId,
      status,
      note: note,
    );
    return AdoptionApplicationUiModel.fromApiJson(item);
  }

  Future<String> updateOwnerNotes(int applicationId, String notes) async {
    final result = await _remote.updateOwnerNotes(applicationId, notes);
    return result['ownerNotes']?.toString() ?? notes;
  }

  Future<void> reportAdoption(
    int adoptionId,
    String reasonCode, {
    String? details,
  }) => _remote.reportAdoption(adoptionId, reasonCode, details: details);

  Future<List<AnimalTypeDto>> fetchAnimalTypes() => _remote.fetchAnimalTypes();

  Future<List<BreedDto>> fetchBreedsByType(int typeId) =>
      _remote.fetchBreedsByType(typeId);
}
