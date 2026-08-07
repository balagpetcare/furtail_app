import 'dart:io';
import 'dart:math';

import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import '../models/pet_model.dart';
import '../pet_api_envelope.dart';

class PetRemoteDs {
  PetRemoteDs({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  final Random _random = Random.secure();

  // -----------------------------
  // Common lookups
  // -----------------------------
  Future<List<Map<String, dynamic>>> getAnimalTypes() async {
    final url = ApiEndpoints.animalTypes();
    final res = await _client.get(url, auth: false);
    return PetApiEnvelope.collectionItems(res, url: url);
  }

  Future<List<Map<String, dynamic>>> getBreeds(int typeId) async {
    final url = ApiEndpoints.breedsByType(typeId);
    final res = await _client.get(url, auth: false);
    return PetApiEnvelope.collectionItems(res, url: url);
  }

  // -----------------------------
  // Pets
  // -----------------------------
  Future<List<Map<String, dynamic>>> getAllPets() async {
    final url = ApiEndpoints.allPets();
    final res = await _client.get(url);
    return PetApiEnvelope.collectionItems(res, url: url);
  }

  Future<List<PetModel>> getMyPets() async {
    final items = await getAllPets();
    return items.map(PetModel.fromJson).toList(growable: false);
  }

  Future<PetModel> getPet(int petId) async {
    final url = ApiEndpoints.updatePet(petId);
    final res = await _client.get(url);
    return PetModel.fromJson(PetApiEnvelope.resourceItem(res, url: url));
  }

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

  Future<PetModel> registerPet(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final url = ApiEndpoints.registerPet();
    final res = await _client.post(
      url,
      _withoutClientOwnerIds(payload),
      headers: {'Idempotency-Key': idempotencyKey ?? _newIdempotencyKey()},
    );
    final item = PetApiEnvelope.resourceItem(res, url: url);
    final id = item['id'];
    if (id is num) return PetModel.fromJson(item);
    throw PetApiEnvelope.malformed(url, details: 'pet id missing');
  }

  Future<PetModel> registerPetWithOptionalPhoto({
    required Map<String, dynamic> payload,
    File? photoFile,
    String? idempotencyKey,
  }) async {
    final finalPayload = <String, dynamic>{...payload};
    if (photoFile != null) {
      final mediaId = await uploadMedia(photoFile);
      finalPayload['profileImageId'] = mediaId;
    }
    return registerPet(finalPayload, idempotencyKey: idempotencyKey);
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

  String _newIdempotencyKey() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = _random.nextInt(1 << 32).toRadixString(16);
    return 'furtail-pet-create-$millis-$suffix';
  }

  Map<String, dynamic> _withoutClientOwnerIds(Map<String, dynamic> payload) {
    final next = Map<String, dynamic>.from(payload)
      ..remove('ownerUserId')
      ..remove('userId');
    return next;
  }
}
