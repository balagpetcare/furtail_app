import 'package:bpa_app/features/common/data/models/bd_location_models.dart';
import 'package:bpa_app/features/location/data/location_repository.dart';
import 'package:bpa_app/services/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocationSelectionState {
  final int? divisionId;
  final int? districtId;
  final int? upazilaId;
  final int? unionId;

  const LocationSelectionState({
    this.divisionId,
    this.districtId,
    this.upazilaId,
    this.unionId,
  });

  LocationSelectionState copyWith({
    int? divisionId,
    int? districtId,
    int? upazilaId,
    int? unionId,
    bool resetDistrict = false,
    bool resetUpazila = false,
    bool resetUnion = false,
  }) {
    return LocationSelectionState(
      divisionId: divisionId ?? this.divisionId,
      districtId: resetDistrict ? null : (districtId ?? this.districtId),
      upazilaId: resetUpazila ? null : (upazilaId ?? this.upazilaId),
      unionId: resetUnion ? null : (unionId ?? this.unionId),
    );
  }
}

class LocationSelectionNotifier extends StateNotifier<LocationSelectionState> {
  LocationSelectionNotifier() : super(const LocationSelectionState());

  void setDivision(int? id) {
    state = state.copyWith(
      divisionId: id,
      resetDistrict: true,
      resetUpazila: true,
      resetUnion: true,
    );
  }

  void setDistrict(int? id) {
    state = state.copyWith(
      districtId: id,
      resetUpazila: true,
      resetUnion: true,
    );
  }

  void setUpazila(int? id) {
    state = state.copyWith(
      upazilaId: id,
      resetUnion: true,
    );
  }

  void setUnion(int? id) {
    state = state.copyWith(unionId: id);
  }

  void hydrate(LocationSelectionState next) {
    state = next;
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final client = ref.read(apiClientProvider);
  return LocationRepository(client);
});

final locationSelectionProvider =
    StateNotifierProvider<LocationSelectionNotifier, LocationSelectionState>(
  (ref) => LocationSelectionNotifier(),
);

final locationDivisionsProvider = FutureProvider<List<BdDivision>>((ref) async {
  final repo = ref.read(locationRepositoryProvider);
  return repo.getDivisions();
});

final locationDistrictsProvider =
    FutureProvider.family<List<BdDistrict>, int>((ref, divisionId) async {
  final repo = ref.read(locationRepositoryProvider);
  return repo.getDistricts(divisionId: divisionId);
});

final locationUpazilasProvider =
    FutureProvider.family<List<BdUpazila>, int>((ref, districtId) async {
  final repo = ref.read(locationRepositoryProvider);
  return repo.getUpazilas(districtId: districtId);
});

final locationUnionsProvider =
    FutureProvider.family<List<BdUnion>, int>((ref, upazilaId) async {
  final repo = ref.read(locationRepositoryProvider);
  return repo.getUnions(upazilaId: upazilaId);
});

final locationPrefetchProvider = FutureProvider.family<void, int>((ref, divisionId) async {
  final repo = ref.read(locationRepositoryProvider);
  await repo.prefetchForDivision(divisionId);
});

