import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import '../models/animal_taxonomy_models.dart';

/// Canonical animal taxonomy repository (species/type -> breed). Never
/// hardcode this list in Flutter; always resolve it here. All reads are
/// unauthenticated public reference-data lookups.
class AnimalTaxonomyRepository {
  final ApiClient _client;
  AnimalTaxonomyRepository(this._client);

  List<Map<String, dynamic>> _items(dynamic res) {
    final data = (res is Map && res['data'] != null) ? res['data'] : res;
    final items = data is Map ? data['items'] : null;
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<AnimalTypeModel>> getAnimalTypes({String? q}) async {
    final res = await _client.get(ApiEndpoints.animalTypes(q: q), auth: false);
    return _items(res).map(AnimalTypeModel.fromJson).toList();
  }

  Future<List<BreedModel>> getBreeds({
    required int animalTypeId,
    String? q,
  }) async {
    final res = await _client.get(
      ApiEndpoints.breedsByType(animalTypeId, q: q),
      auth: false,
    );
    return _items(res).map(BreedModel.fromJson).toList();
  }

  Future<BreedModel?> getBreedById(int id) async {
    final res = await _client.get(ApiEndpoints.breedById(id), auth: false);
    final data = (res is Map && res['data'] != null) ? res['data'] : res;
    if (data is! Map) return null;
    return BreedModel.fromJson(Map<String, dynamic>.from(data));
  }
}
