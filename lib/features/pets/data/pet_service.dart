import 'dart:io';

import 'package:furtail_app/core/network/api_config.dart';
import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import 'models/pet_model.dart';
import 'models/pet_profile_model.dart';
import 'pet_api_envelope.dart';

class PetService {
  PetService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  // Owner: My Pets
  Future<List<PetModel>> getMyPets() async {
    final url = ApiEndpoints.allPets();
    final res = await _client.get(url);
    return PetApiEnvelope.collectionItems(
      res,
      url: url,
    ).map(PetModel.fromJson).toList(growable: false);
  }

  Future<PetProfileModel> getPetProfile(int petId) async {
    final url = '${ApiConfig.apiV1}/user/pets/$petId/profile';
    final res = await _client.get(url);
    return PetProfileModel.fromJson(PetApiEnvelope.resourceItem(res, url: url));
  }

  Future<Map<String, dynamic>> getPet(int petId) async {
    final url = ApiEndpoints.updatePet(petId);
    final res = await _client.get(url);
    return PetApiEnvelope.resourceItem(res, url: url);
  }

  Future<Map<String, dynamic>> registerPet(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final url = ApiEndpoints.registerPet();
    final res = await _client.post(
      url,
      _withoutClientOwnerIds(payload),
      headers: {
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'Idempotency-Key': idempotencyKey,
      },
    );
    return PetApiEnvelope.resourceItem(res, url: url);
  }

  Future<PetModel> updatePet(int petId, Map<String, dynamic> payload) async {
    final url = ApiEndpoints.updatePet(petId);
    final res = await _client.patch(url, _withoutClientOwnerIds(payload));
    return PetModel.fromJson(PetApiEnvelope.resourceItem(res, url: url));
  }

  Future<PetModel?> deletePet(int petId) async {
    final url = ApiEndpoints.deletePet(petId);
    final res = await _client.delete(url);
    if (res == null) return null;
    try {
      return PetModel.fromJson(PetApiEnvelope.resourceItem(res, url: url));
    } on ApiClientException {
      return null;
    }
  }

  // Media upload
  Future<int> uploadMedia(File file) async {
    final url = ApiEndpoints.mediaUpload();
    final res = await _client.multipartPostTyped<dynamic>(
      url: url,
      files: [ApiMultipartFilePart(fieldName: 'file', file: file)],
      fields: const {'purpose': 'pet_profile_image', 'contentType': 'PET'},
      parse: (decoded) => decoded,
    );
    final item = PetApiEnvelope.resourceItem(res, url: url);
    final mediaId = item['id'];
    if (mediaId is num) return mediaId.toInt();
    throw PetApiEnvelope.malformed(url, details: 'media id missing');
  }

  // Public pet profile
  Future<PetModel> getPublicPet(int petId) async {
    final url = '${ApiConfig.apiV1}/pets/$petId';
    final res = await _client.get(url);
    return PetModel.fromJson(PetApiEnvelope.resourceItem(res, url: url));
  }

  Future<PetModel> getPetBySlug(String slug) async {
    final url = '${ApiConfig.apiV1}/pets/slug/$slug';
    final res = await _client.get(url);
    return PetModel.fromJson(PetApiEnvelope.resourceItem(res, url: url));
  }

  Future<void> updatePetPublicProfile(
    int petId,
    Map<String, dynamic> payload,
  ) async {
    final url = '${ApiConfig.apiV1}/pets/$petId/profile';
    await _client.patch(url, _withoutClientOwnerIds(payload));
  }

  // Pet social actions
  Future<void> followPet(int petId) async {
    await _client.post('${ApiConfig.apiV1}/pets/$petId/follow', const {});
  }

  Future<void> unfollowPet(int petId) async {
    await _client.delete('${ApiConfig.apiV1}/pets/$petId/follow');
  }

  Future<void> likePet(int petId) async {
    await _client.post('${ApiConfig.apiV1}/pets/$petId/like', const {});
  }

  Future<void> unlikePet(int petId) async {
    await _client.delete('${ApiConfig.apiV1}/pets/$petId/like');
  }

  Future<Map<String, dynamic>> getPetSocialStatus(int petId) async {
    final url = '${ApiConfig.apiV1}/pets/$petId/social-status';
    final res = await _client.get(url);
    return PetApiEnvelope.resourceItem(res, url: url);
  }

  // Pet posts
  Future<List<Map<String, dynamic>>> getPetPosts(
    int petId, {
    int? cursor,
    int limit = 20,
  }) async {
    final params = {'limit': '$limit', if (cursor != null) 'cursor': '$cursor'};
    final uri = Uri.parse(
      '${ApiConfig.apiV1}/pets/$petId/posts',
    ).replace(queryParameters: params);
    final url = uri.toString();
    final res = await _client.get(url);
    return PetApiEnvelope.collectionItems(res, url: url);
  }

  Future<Map<String, dynamic>> createPetPost(
    int petId,
    Map<String, dynamic> payload,
  ) async {
    final url = '${ApiConfig.apiV1}/pets/$petId/posts';
    final res = await _client.post(url, _withoutClientOwnerIds(payload));
    return PetApiEnvelope.resourceItem(res, url: url);
  }

  Map<String, dynamic> _withoutClientOwnerIds(Map<String, dynamic> payload) {
    return Map<String, dynamic>.from(payload)
      ..remove('ownerUserId')
      ..remove('userId');
  }
}
