import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/core/network/api_config.dart';
import 'package:furtail_app/core/network/multipart_helper.dart';
import 'models/pet_model.dart';
import 'models/pet_profile_model.dart';

class PetService {
  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString("token");
  }

  Map<String, String> _authHeaders(String token) => {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      };

  Map<String, String> _jsonHeaders(String token) => {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

  Map<String, String> _optionalAuthHeaders(String? token) => {
        if (token != null) "Authorization": "Bearer $token",
        "Accept": "application/json",
      };

  // ── Owner: My Pets ─────────────────────────────────────────────────────────

  Future<List<PetModel>> getMyPets() async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.get(
      Uri.parse("${ApiConfig.apiV1}/user/pets/all"),
      headers: _authHeaders(token),
    );

    if (res.statusCode != 200) throw Exception(res.body);

    final data = jsonDecode(res.body);
    final list = (data["data"] is List)
        ? data["data"]
        : (data["pets"] ?? data["data"]?["pets"] ?? []);

    return (list as List)
        .map((e) => PetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PetProfileModel> getPetProfile(int petId) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.get(
      Uri.parse("${ApiConfig.apiV1}/user/pets/$petId/profile"),
      headers: _authHeaders(token),
    );

    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    return PetProfileModel.fromJson(
        (data["data"] ?? {}) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getPet(int petId) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.get(
      Uri.parse("${ApiConfig.apiV1}/user/pets/$petId"),
      headers: _authHeaders(token),
    );

    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    return (data["data"] ?? {}) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> registerPet(
      Map<String, dynamic> payload) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.post(
      Uri.parse("${ApiConfig.apiV1}/user/pets/register"),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updatePet(int petId, Map<String, dynamic> payload) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.patch(
      Uri.parse("${ApiConfig.apiV1}/user/pets/$petId"),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> deletePet(int petId) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.delete(
      Uri.parse("${ApiConfig.apiV1}/user/pets/$petId"),
      headers: _authHeaders(token),
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(res.body);
    }
  }

  // ── Media upload ──────────────────────────────────────────────────────────

  Future<int> uploadMedia(File file) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final req = http.MultipartRequest(
      "POST",
      Uri.parse("${ApiConfig.apiV1}/media/upload"),
    );

    req.headers.addAll(_authHeaders(token));
    final mf = await multipartFromAnyFile(file);
    req.files.add(mf);

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(body);
    }

    final decoded = jsonDecode(body);
    final mediaId = decoded["data"]?["id"];
    if (mediaId == null) throw Exception("mediaId missing: $body");
    return (mediaId as num).toInt();
  }

  // ── Public pet profile ────────────────────────────────────────────────────

  Future<PetModel> getPublicPet(int petId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse("${ApiConfig.apiV1}/pets/$petId"),
      headers: _optionalAuthHeaders(token),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    return PetModel.fromJson((data["data"] ?? {}) as Map<String, dynamic>);
  }

  Future<PetModel> getPetBySlug(String slug) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse("${ApiConfig.apiV1}/pets/slug/$slug"),
      headers: _optionalAuthHeaders(token),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    return PetModel.fromJson((data["data"] ?? {}) as Map<String, dynamic>);
  }

  // ── Pet public profile update (owner) ─────────────────────────────────────

  Future<void> updatePetPublicProfile(
      int petId, Map<String, dynamic> payload) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.patch(
      Uri.parse("${ApiConfig.apiV1}/pets/$petId/profile"),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) throw Exception(res.body);
  }

  // ── Pet social actions ────────────────────────────────────────────────────

  Future<void> followPet(int petId) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.post(
      Uri.parse("${ApiConfig.apiV1}/pets/$petId/follow"),
      headers: _authHeaders(token),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> unfollowPet(int petId) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.delete(
      Uri.parse("${ApiConfig.apiV1}/pets/$petId/follow"),
      headers: _authHeaders(token),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> likePet(int petId) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.post(
      Uri.parse("${ApiConfig.apiV1}/pets/$petId/like"),
      headers: _authHeaders(token),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> unlikePet(int petId) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.delete(
      Uri.parse("${ApiConfig.apiV1}/pets/$petId/like"),
      headers: _authHeaders(token),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<Map<String, dynamic>> getPetSocialStatus(int petId) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.get(
      Uri.parse("${ApiConfig.apiV1}/pets/$petId/social-status"),
      headers: _authHeaders(token),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    return (data["data"] ?? {}) as Map<String, dynamic>;
  }

  // ── Pet posts ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPetPosts(int petId,
      {int? cursor, int limit = 20}) async {
    final token = await _token();
    final params = {
      "limit": "$limit",
      if (cursor != null) "cursor": "$cursor",
    };
    final uri = Uri.parse("${ApiConfig.apiV1}/pets/$petId/posts")
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _optionalAuthHeaders(token));
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);
    return ((data["data"] ?? []) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createPetPost(
      int petId, Map<String, dynamic> payload) async {
    final token = await _token();
    if (token == null) throw Exception("No token found");

    final res = await http.post(
      Uri.parse("${ApiConfig.apiV1}/pets/$petId/posts"),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(res.body);
    }
    return (jsonDecode(res.body)["data"] ?? {}) as Map<String, dynamic>;
  }
}
