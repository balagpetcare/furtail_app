import 'package:bpa_app/core/network/api_endpoints.dart';
import 'package:bpa_app/services/api_client.dart';

import '../models/bd_location_models.dart';

class BdLocationsRepository {
  final ApiClient _client;
  BdLocationsRepository(this._client);

  Future<List<BdDivision>> getDivisions() async {
    final res = await _client.get(ApiEndpoints.bdDivisions());
    final list = (res is Map ? res['items'] : null) as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(BdDivision.fromJson).toList();
  }

  Future<List<BdDistrict>> getDistricts({required int divisionId}) async {
    final res = await _client.get(ApiEndpoints.bdDistricts(divisionId: divisionId));
    final list = (res is Map ? res['items'] : null) as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(BdDistrict.fromJson).toList();
  }

  Future<List<BdUpazila>> getUpazilas({required int districtId}) async {
    final res = await _client.get(ApiEndpoints.bdUpazilas(districtId: districtId));
    final list = (res is Map ? res['items'] : null) as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(BdUpazila.fromJson).toList();
  }

  Future<List<BdArea>> getAreas({required int upazilaId}) async {
    final res = await _client.get(ApiEndpoints.bdAreas(upazilaId: upazilaId));
    final list = (res is Map ? res['items'] : null) as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(BdArea.fromJson).toList();
  }

  Future<List<BdArea>> getCityCorporations({required int districtId}) async {
    final res = await _client.get(ApiEndpoints.bdCityCorporations(districtId: districtId));
    final list = (res is Map ? res['items'] : null) as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(BdArea.fromJson).toList();
  }

  Future<List<BdArea>> getZones({required int cityCorporationId}) async {
    final res = await _client.get(ApiEndpoints.bdZones(cityCorporationId: cityCorporationId));
    final list = (res is Map ? res['items'] : null) as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(BdArea.fromJson).toList();
  }

  Future<List<BdArea>> getCcAreas({required int zoneId}) async {
    final res = await _client.get(ApiEndpoints.bdCcAreas(zoneId: zoneId));
    final list = (res is Map ? res['items'] : null) as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(BdArea.fromJson).toList();
  }

}
