import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/features/common/data/models/country_reference_model.dart';
import 'package:furtail_app/services/api_client.dart';

class AdoptionRemoteDs {
  final ApiClient _api;
  final SecureStorageService _secureStorage;

  AdoptionRemoteDs(this._api, [SecureStorageService? secureStorage])
    : _secureStorage = secureStorage ?? SecureStorageService();

  dynamic _data(dynamic res) {
    if (res is Map && res['data'] != null) return res['data'];
    return res;
  }

  List<Map<String, dynamic>> _extractAdoptionItems(dynamic res) {
    final data = _data(res);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      final items = data['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  Future<bool> _hasToken() => _secureStorage.hasSession;

  Future<List<Map<String, dynamic>>> fetchAdoptions({
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
    final auth = await _hasToken();
    final res = await _api.get(
      ApiEndpoints.adoptionFeed(
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
      ),
      auth: auth,
    );
    return _extractAdoptionItems(res);
  }

  Future<Map<String, dynamic>> fetchAdoptionDetail(int id) async {
    final res = await _api.get(
      ApiEndpoints.adoptionDetail(id),
      auth: await _hasToken(),
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption detail response');
  }

  Future<Map<String, dynamic>> favoriteAdoption(int id) async {
    final res = await _api.post(
      ApiEndpoints.favoriteAdoption(id),
      const {},
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption favorite response');
  }

  Future<Map<String, dynamic>> unfavoriteAdoption(int id) async {
    final res = await _api.delete(
      ApiEndpoints.unfavoriteAdoption(id),
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption unfavorite response');
  }

  Future<Map<String, dynamic>> listAdoptionComments(
    int id, {
    int limit = 50,
  }) async {
    final res = await _api.get(
      ApiEndpoints.adoptionComments(id, limit: limit),
      auth: await _hasToken(),
    );
    final data = _data(res);
    if (data is! List) {
      final meta = (res is Map<String, dynamic> ? res['meta'] : null);
      return <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        if (meta is Map) 'meta': Map<String, dynamic>.from(meta),
      };
    }
    final meta = (res is Map<String, dynamic> ? res['meta'] : null);
    return <String, dynamic>{
      'items': data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      if (meta is Map) 'meta': Map<String, dynamic>.from(meta),
    };
  }

  Future<Map<String, dynamic>> addAdoptionComment(int id, String text) async {
    final res = await _api.post(ApiEndpoints.addAdoptionComment(id), {
      'text': text,
    }, auth: true);
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption comment create response');
  }

  Future<Map<String, dynamic>> deleteAdoptionComment(
    int id,
    int commentId,
  ) async {
    final res = await _api.delete(
      ApiEndpoints.deleteAdoptionComment(id, commentId),
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid adoption comment delete response');
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

  Future<CountryReferenceModel> fetchBangladeshCountry() async {
    final res = await _api.get(ApiEndpoints.publicCountries, auth: false);
    final data = _data(res);
    if (data is! List) {
      throw Exception('Could not load country list.');
    }
    final countries = data
        .whereType<Map>()
        .map(
          (entry) =>
              CountryReferenceModel.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();
    for (final country in countries) {
      if (country.isBangladesh) {
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
      ApiEndpoints.adoptionApplications(adoptionId),
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
    final res = await _api.get(
      ApiEndpoints.myAdoptionApplications(),
      auth: true,
    );
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchApplicationsForMyListing(
    int adoptionId, {
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    String url = ApiEndpoints.myAdoptionListingApplications(adoptionId);
    url += '?page=$page&limit=$limit';
    if (status != null && status.isNotEmpty) {
      url += '&status=$status';
    }
    final res = await _api.get(url, auth: true);
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> fetchAdoptionApplicationDetail(
    int applicationId,
  ) async {
    final res = await _api.get(
      ApiEndpoints.adoptionApplicationDetail(applicationId),
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid application detail response');
  }

  Future<Map<String, dynamic>> updateAdoptionApplicationStatus(
    int applicationId,
    String status, {
    String? note,
  }) async {
    final payload = <String, dynamic>{'status': status};
    if (note != null) {
      payload['note'] = note;
    }
    final res = await _api.post(
      ApiEndpoints.updateAdoptionApplicationStatus(applicationId),
      payload,
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid update application status response');
  }

  Future<Map<String, dynamic>> updateOwnerNotes(
    int applicationId,
    String notes,
  ) async {
    final res = await _api.patch(
      ApiEndpoints.updateAdoptionApplicationNotes(applicationId),
      {'notes': notes},
      auth: true,
    );
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Failed to update owner notes');
  }

  Future<void> reportAdoption(
    int adoptionId,
    String reasonCode, {
    String? details,
  }) async {
    final res = await _api.post(ApiEndpoints.reportAdoption(adoptionId), {
      'reasonCode': reasonCode,
      if (details != null && details.isNotEmpty) 'details': details,
    }, auth: true);
    final data = _data(res);
    if (data == null && res is Map && res['success'] == true) return;
    if (data != null) return;
    throw Exception('Failed to submit report');
  }

  Future<Map<String, dynamic>> updateAdoptionListingStatus(
    int id,
    String status,
  ) async {
    final res = await _api.patch(ApiEndpoints.updateAdoptionStatus(id), {
      'status': status,
    }, auth: true);
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid status update response');
  }

  Future<Map<String, dynamic>> deleteAdoptionListing(int id) async {
    final res = await _api.delete(ApiEndpoints.deleteAdoption(id), auth: true);
    final data = _data(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid delete response');
  }
}
