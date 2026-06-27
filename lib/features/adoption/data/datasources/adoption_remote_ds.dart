import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/features/legacy/data/models/country_model.dart';
import 'package:furtail_app/services/api_client.dart';

class AdoptionRemoteDs {
  final ApiClient _api;

  AdoptionRemoteDs(this._api);

  dynamic _data(dynamic res) {
    if (res is Map && res['data'] != null) return res['data'];
    return res;
  }

  Future<List<Map<String, dynamic>>> fetchAdoptions({
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
    final res = await _api.get(
      ApiEndpoints.adoptions(
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
      ),
      auth: false,
    );
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> fetchAdoptionDetail(int id) async {
    final res = await _api.get(ApiEndpoints.adoptionDetail(id), auth: false);
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption detail response');
  }

  Future<Map<String, dynamic>> createAdoptionListing(
    Map<String, dynamic> payload,
  ) async {
    final res = await _api.post(
      ApiEndpoints.createAdoption(),
      payload,
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption create response');
  }

  Future<Map<String, dynamic>> updateAdoptionListing(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _api.patch(
      ApiEndpoints.updateAdoption(id),
      payload,
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption update response');
  }

  Future<Map<String, dynamic>> submitAdoptionForReview(int id) async {
    final res = await _api.post(
      ApiEndpoints.submitAdoptionReview(id),
      const {},
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption submit response');
  }

  Future<Country> fetchBangladeshCountry() async {
    final res = await _api.get(ApiEndpoints.publicCountries, auth: false);
    final data = _data(res);
    if (data is! List) {
      throw Exception('Could not load country list.');
    }
    final countries = data
        .whereType<Map>()
        .map((entry) => Country.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
    for (final country in countries) {
      final iso2 = country.iso2.trim().toUpperCase();
      final name = country.name.trim().toLowerCase();
      if (iso2 == 'BD' || name == 'bangladesh') {
        return country;
      }
    }
    throw Exception('Bangladesh is not configured in the country list.');
  }

  Future<Map<String, dynamic>> applyToAdopt(
    int adoptionId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _api.post(
      '${ApiEndpoints.adoptionDetail(adoptionId)}/apply',
      payload,
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption application response');
  }

  Future<List<Map<String, dynamic>>> fetchMyAdoptionListings() async {
    final res = await _api.get(ApiEndpoints.myAdoptions(), auth: true);
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMyAdoptionApplications() async {
    final res = await _api.get(ApiEndpoints.myAdoptionApplications(), auth: true);
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
