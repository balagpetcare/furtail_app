import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/fundraising_models.dart';

class FundraisingApi {
  final String baseUrl; // e.g. https://api.example.com/api/v1
  final Future<String?> Function() getAuthToken;

  FundraisingApi({required this.baseUrl, required this.getAuthToken});

  Future<Map<String, String>> _headers() async {
    final token = await getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<FundraisingCampaign> getCampaign(int id) async {
    final res = await http.get(
      _u('/fundraising/campaigns/$id'),
      headers: await _headers(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load campaign');
    }
    return FundraisingCampaign.fromJson(
      (body['data'] as Map).cast<String, dynamic>(),
    );
  }

  Future<List<DonationItem>> listDonations(
    int campaignId, {
    int limit = 50,
  }) async {
    final res = await http.get(
      _u('/fundraising/campaigns/$campaignId/donations', {'limit': '$limit'}),
      headers: await _headers(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load donations');
    }
    final list = (body['data'] as List).cast<Map>();
    return list
        .map((e) => DonationItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<FundraisingUpdateItem>> listUpdates(
    int campaignId, {
    int limit = 50,
  }) async {
    final res = await http.get(
      _u('/fundraising/campaigns/$campaignId/updates', {'limit': '$limit'}),
      headers: await _headers(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load updates');
    }
    final list = (body['data'] as List).cast<Map>();
    return list
        .map((e) => FundraisingUpdateItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> donate(int campaignId, int amount) async {
    final res = await http.post(
      _u('/fundraising/campaigns/$campaignId/donate'),
      headers: await _headers(),
      body: jsonEncode({'amount': amount}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Donation failed');
    }
  }

  Future<void> createUpdate(int campaignId, {required String text}) async {
    final res = await http.post(
      _u('/fundraising/campaigns/$campaignId/updates'),
      headers: await _headers(),
      body: jsonEncode({'text': text}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to create update');
    }
  }
}
