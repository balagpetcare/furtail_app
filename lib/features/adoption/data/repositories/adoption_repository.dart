import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
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
    int? countryId,
    int? divisionId,
    int? stateId,
    int? districtId,
    int? cityId,
    int? areaId,
    int page = 1,
    int limit = 20,
  }) async {
    final items = await _remote.fetchAdoptions(
      species: species,
      search: search,
      countryId: countryId,
      divisionId: divisionId,
      stateId: stateId,
      districtId: districtId,
      cityId: cityId,
      areaId: areaId,
      page: page,
      limit: limit,
    );
    return items.map(AdoptionPetUiModel.fromApiJson).toList();
  }

  Future<AdoptionPetUiModel> fetchAdoptionDetail(int id) async {
    final item = await _remote.fetchAdoptionDetail(id);
    return AdoptionPetUiModel.fromApiJson(item);
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
}
