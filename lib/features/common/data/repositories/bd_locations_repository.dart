import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import '../models/bd_location_models.dart';

/// Canonical Bangladesh location repository. Talks to the backend's public
/// reference-data endpoints only — never holds its own authoritative
/// division/district/upazila/union/area list. Every read is unauthenticated
/// (`auth: false`) so a normal mobile user is never blocked by a missing
/// admin role while filling out a form.
class BdLocationsRepository {
  final ApiClient _client;
  BdLocationsRepository(this._client);

  /// The backend wraps list responses as
  /// `{success, data: {items, total, page, pageSize}, meta}`. Unwrap `data`
  /// first, then read `items` — reading `items` directly off the envelope
  /// (as this repository previously did) always returned an empty list.
  List<Map<String, dynamic>> _items(dynamic res) {
    final data = (res is Map && res['data'] != null) ? res['data'] : res;
    final items = (data is Map ? data['items'] : null) as List<dynamic>?;
    return (items ?? const []).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<BdDivision>> getDivisions({String? q}) async {
    final res = await _client.get(ApiEndpoints.bdDivisions(), auth: false);
    return _items(res).map(BdDivision.fromJson).toList();
  }

  Future<List<BdDistrict>> getDistricts({required int divisionId}) async {
    final res = await _client.get(
      ApiEndpoints.bdDistricts(divisionId: divisionId),
      auth: false,
    );
    return _items(res).map(BdDistrict.fromJson).toList();
  }

  Future<List<BdUpazila>> getUpazilas({required int districtId}) async {
    final res = await _client.get(
      ApiEndpoints.bdUpazilas(districtId: districtId),
      auth: false,
    );
    return _items(res).map(BdUpazila.fromJson).toList();
  }

  /// Areas directly under an upazila (rural, no explicit union) or filtered
  /// by union/parent — pass whichever scope is relevant.
  Future<List<BdArea>> getAreas({
    int? upazilaId,
    int? unionId,
    int? parentId,
  }) async {
    final res = await _client.get(
      ApiEndpoints.bdAreas(
        upazilaId: upazilaId,
        unionId: unionId,
        parentId: parentId,
      ),
      auth: false,
    );
    return _items(res).map(BdArea.fromJson).toList();
  }

  Future<List<BdUnion>> getUnions({required int upazilaId}) async {
    final res = await _client.get(
      ApiEndpoints.locationMasterUnions(upazilaId: upazilaId),
      auth: false,
    );
    return _items(res).map(BdUnion.fromJson).toList();
  }

  /// Urban branch — City Corporation -> Zone -> Ward/Area, anchored to a
  /// district. Never requires a union/upazila selection.
  Future<List<BdArea>> getCityCorporations({required int districtId}) async {
    final res = await _client.get(
      ApiEndpoints.bdCityCorporations(districtId: districtId),
      auth: false,
    );
    return _items(res).map(BdArea.fromJson).toList();
  }

  Future<List<BdArea>> getZones({required int cityCorporationId}) async {
    final res = await _client.get(
      ApiEndpoints.bdZones(cityCorporationId: cityCorporationId),
      auth: false,
    );
    return _items(res).map(BdArea.fromJson).toList();
  }

  Future<List<BdArea>> getWards({required int zoneId}) async {
    final res = await _client.get(
      ApiEndpoints.bdCcAreas(zoneId: zoneId),
      auth: false,
    );
    return _items(res).map(BdArea.fromJson).toList();
  }

  /// Backwards-compatible alias for older callers.
  Future<List<BdArea>> getCcAreas({required int zoneId}) {
    return getWards(zoneId: zoneId);
  }

  Future<List<BdArea>> getAreasByWard({required int wardId}) async {
    final res = await _client.get(
      ApiEndpoints.bdAreas(parentId: wardId),
      auth: false,
    );
    return _items(res).map(BdArea.fromJson).toList();
  }

  Future<BdArea?> getAreaById(int id) async {
    final res = await _client.get(ApiEndpoints.bdAreaById(id), auth: false);
    final data = (res is Map && res['data'] != null) ? res['data'] : res;
    if (data is Map<String, dynamic>) {
      return BdArea.fromJson(data);
    }
    return null;
  }

  Future<Map<String, dynamic>> validateSelection({
    int? divisionId,
    int? districtId,
    int? upazilaId,
    int? unionId,
    int? areaId,
    int? cityCorporationId,
    int? zoneId,
    int? wardId,
  }) async {
    final res = await _client
        .post(ApiEndpoints.locationMasterValidateSelection(), <String, dynamic>{
          if (divisionId != null) 'divisionId': divisionId,
          if (districtId != null) 'districtId': districtId,
          if (upazilaId != null) 'upazilaId': upazilaId,
          if (unionId != null) 'unionId': unionId,
          if (areaId != null) 'areaId': areaId,
          if (cityCorporationId != null) 'cityCorporationId': cityCorporationId,
          if (zoneId != null) 'zoneId': zoneId,
          if (wardId != null) 'wardId': wardId,
        }, auth: false);
    if (res is Map && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return const <String, dynamic>{};
  }
}
