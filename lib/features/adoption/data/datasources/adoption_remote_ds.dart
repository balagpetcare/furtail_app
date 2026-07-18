import 'dart:convert';

import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/dtos/pets/animal_type_dto.dart';
import 'package:furtail_app/dtos/pets/breed_dto.dart';
import 'package:furtail_app/features/legacy/data/models/country_model.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:http/http.dart' as http;

class AdoptionRemoteDs {
  final ApiClient _api;
  final SecureStorageService _secureStorage;

  AdoptionRemoteDs(this._api, [SecureStorageService? secureStorage])
    : _secureStorage = secureStorage ?? SecureStorageService();

  dynamic _data(dynamic res) {
    if (res is Map && res['data'] != null) return res['data'];
    return res;
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
      ApiEndpoints.adoptions(
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
    final data = _data(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
    final res = await _api.post(
      ApiEndpoints.updateAdoptionApplicationStatus(applicationId),
      {'status': status, if (note != null) 'note': note},
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

  Future<List<AnimalTypeDto>> fetchAnimalTypes() async {
    final res = await http.get(Uri.parse(ApiEndpoints.animalTypes()));
    if (res.statusCode != 200) throw Exception('Failed to load animal types');
    final json = jsonDecode(res.body);
    final list = (json['types'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    return list.map(AnimalTypeDto.fromJson).toList();
  }

  Future<List<BreedDto>> fetchBreedsByType(int typeId) async {
    final res = await http.get(Uri.parse(ApiEndpoints.breedsByType(typeId)));
    if (res.statusCode != 200) throw Exception('Failed to load breeds');
    final json = jsonDecode(res.body);
    final list = (json['breeds'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    return list.map(BreedDto.fromJson).toList();
  }
}
