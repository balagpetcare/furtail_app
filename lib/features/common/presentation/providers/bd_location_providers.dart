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

/// CC Areas (by zone) ✅ BdArea list
final bdCcAreasProvider = FutureProvider.family<List<BdArea>, int>((
  ref,
  zoneId,
) async {
  final repo = ref.read(bdLocationsRepositoryProvider);
  return repo.getCcAreas(zoneId: zoneId);
});
