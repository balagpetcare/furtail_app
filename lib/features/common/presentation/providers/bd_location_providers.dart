import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/services/api_client.dart';

import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/common/data/repositories/bd_locations_repository.dart';

//D:\BPA_Data\Flutter APP\furtail_app\lib\services\api_client.dart
/// Repo provider
final bdLocationsRepositoryProvider = Provider<BdLocationsRepository>((ref) {
  final client = ref.read(apiClientProvider);
  return BdLocationsRepository(client);
});

/// Divisions
final bdDivisionsProvider = FutureProvider<List<BdDivision>>((ref) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getDivisions();
});

/// Districts (by division)
final bdDistrictsProvider = FutureProvider.family<List<BdDistrict>, int>((
  ref,
  divisionId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getDistricts(divisionId: divisionId);
});

/// Upazilas (by district)
final bdUpazilasProvider = FutureProvider.family<List<BdUpazila>, int>((
  ref,
  districtId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getUpazilas(districtId: districtId);
});

/// Areas (by upazila)
final bdAreasProvider = FutureProvider.family<List<BdArea>, int>((
  ref,
  upazilaId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getAreas(upazilaId: upazilaId);
});

/// Areas (by union)
final bdAreasByUnionProvider = FutureProvider.family<List<BdArea>, int>((
  ref,
  unionId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getAreas(unionId: unionId);
});

/// Unions (by upazila)
final bdUnionsProvider = FutureProvider.family<List<BdUnion>, int>((
  ref,
  upazilaId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getUnions(upazilaId: upazilaId);
});

/// City Corporations (by district)  ✅ repo অনুযায়ী BdArea list
final bdCityCorporationsProvider = FutureProvider.family<List<BdArea>, int>((
  ref,
  districtId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getCityCorporations(districtId: districtId);
});

/// Zones (by city corporation) ✅ BdArea list
final bdZonesProvider = FutureProvider.family<List<BdArea>, int>((
  ref,
  cityCorporationId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getZones(cityCorporationId: cityCorporationId);
});

/// Wards (by zone) / legacy alias
final bdWardsProvider = FutureProvider.family<List<BdArea>, int>((
  ref,
  zoneId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getWards(zoneId: zoneId);
});

/// CC Areas (legacy alias for wards by zone)
final bdCcAreasProvider = FutureProvider.family<List<BdArea>, int>((
  ref,
  zoneId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getCcAreas(zoneId: zoneId);
});

/// Areas (by ward)
final bdAreasByWardProvider = FutureProvider.family<List<BdArea>, int>((
  ref,
  wardId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getAreasByWard(wardId: wardId);
});

final bdAreaByIdProvider = FutureProvider.family<BdArea?, int>((ref, id) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getAreaById(id);
});
