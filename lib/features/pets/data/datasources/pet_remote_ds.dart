import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/pet_model.dart';

class PetRemoteDs {
  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString("token");
  }

  Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final t = await _token();
    return <String, String>{
      if (t != null) "Authorization": "Bearer $t",
      if (json) "Content-Type": "application/json",
      "Accept": "application/json",
    };
  }

  // -----------------------------
  // Common lookups
  // -----------------------------
  Future<List<Map<String, dynamic>>> getAnimalTypes() async {
    final res = await http.get(Uri.parse(ApiEndpoints.animalTypes()));
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    final list = (data["types"] as List).cast<Map<String, dynamic>>();
    return list;
  }

  Future<List<Map<String, dynamic>>> getBreeds(int typeId) async {
    final res = await http.get(Uri.parse(ApiEndpoints.breedsByType(typeId)));
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    final list = (data["breeds"] as List).cast<Map<String, dynamic>>();
    return list;
  }

  // -----------------------------
  // Pets list
  // -----------------------------
  Future<List<Map<String, dynamic>>> getAllPets() async {
    final res = await http.get(
      Uri.parse(ApiEndpoints.allPets()),
      headers: await _authHeaders(json: false),
    );
    if (res.statusCode != 200) throw Exception(res.body);

    final data = jsonDecode(res.body);
    final list = (data["data"] is List)
        ? data["data"]
        : (data["pets"] ?? data["data"]?["pets"] ?? []);

    return (list as List).cast<Map<String, dynamic>>();
  }

  // -----------------------------
  // ✅ Upload media -> returns mediaId
  // Backend: POST /api/v1/media/upload (field name: file)
  // -----------------------------
  Future<int> uploadMedia(File file) async {
    final t = await _token();
    if (t == null || t.isEmpty) {
      throw Exception("No token found. Please login again.");
    }

    final uri = Uri.parse("${ApiConfig.apiV1}/media/upload");
    final req = http.MultipartRequest("POST", uri);
    req.headers["Authorization"] = "Bearer $t";

    // IMPORTANT: field name must be "file"
    req.files.add(await http.MultipartFile.fromPath("file", file.path));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception("Upload failed (${streamed.statusCode}): $body");
    }

    final decoded = jsonDecode(body);
    final mediaId = decoded["data"]?["id"];
    if (mediaId == null) {
      throw Exception("Upload succeeded but mediaId missing: $body");
    }
    return (mediaId as num).toInt();
  }

  // -----------------------------
  // Register pet (JSON) -> returns petId
  // -----------------------------
  Future<int> registerPet(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse(ApiEndpoints.registerPet()),
      headers: await _authHeaders(json: true),
      body: jsonEncode(payload),
    );

    final body = res.body;
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception("Register failed (${res.statusCode}): $body");
    }

    dynamic data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      throw Exception("Invalid JSON response: $body");
    }

    final id =
        data["data"]?["id"] ??
        data["pet"]?["id"] ??
        data["data"]?["pet"]?["id"];

    if (id == null) throw Exception("Pet id missing: $body");
    return (id as num).toInt();
  }

  // -----------------------------
  // ✅ KEY: create pet + optional photo (NO multipart needed)
  // 1) uploadMedia(file) -> mediaId
  // 2) registerPet(payload + profilePicId)
  // -----------------------------
  Future<int> registerPetWithOptionalPhoto({
    required Map<String, dynamic> payload,
    File? photoFile,
  }) async {
    final finalPayload = <String, dynamic>{...payload};

    if (photoFile != null) {
      final mediaId = await uploadMedia(photoFile); // ✅ /media/upload
      finalPayload["profilePicId"] = mediaId; // ✅ JSON payload এ যাবে
    }

    return registerPet(finalPayload); // ✅ /user/pets/register JSON
  }

  // -----------------------------
  // Update pet (PATCH)
  // -----------------------------
  Future<void> updatePet(int petId, Map<String, dynamic> payload) async {
    final res = await http.patch(
      Uri.parse(ApiEndpoints.updatePet(petId)),
      headers: await _authHeaders(json: true),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  // -----------------------------
  // Convenience list model
  // -----------------------------
  Future<List<PetModel>> getMyPets() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.apiV1}/user/pets/all"),
      headers: await _authHeaders(json: false),
    );

    if (response.statusCode != 200) throw Exception(response.body);

    final data = jsonDecode(response.body);
    final list = (data["data"] is List)
        ? data["data"]
        : (data["pets"] ?? data["data"]?["pets"] ?? []);

    return (list as List)
        .map((e) => PetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
