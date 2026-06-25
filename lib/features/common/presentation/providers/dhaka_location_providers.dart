import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:furtail_app/core/network/api_config.dart';

class DhakaWard {
  final int id;
  final String code;
  final String name;
  DhakaWard({required this.id, required this.code, required this.name});
  factory DhakaWard.fromJson(Map<String, dynamic> j) =>
      DhakaWard(id: j['id'], code: j['code'], name: j['name']);
}

class DhakaZone {
  final int id;
  final String code;
  final String name;
  final List<DhakaWard> wards;
  DhakaZone({required this.id, required this.code, required this.name, required this.wards});
  factory DhakaZone.fromJson(Map<String, dynamic> j) => DhakaZone(
        id: j['id'],
        code: j['code'],
        name: j['name'],
        wards: (j['wards'] as List).map((e) => DhakaWard.fromJson(e)).toList(),
      );
}

class DhakaCorporation {
  final int id;
  final String code;
  final String name;
  final List<DhakaZone> zones;
  DhakaCorporation({required this.id, required this.code, required this.name, required this.zones});
  factory DhakaCorporation.fromJson(Map<String, dynamic> j) => DhakaCorporation(
        id: j['id'],
        code: j['code'],
        name: j['name'],
        zones: (j['zones'] as List).map((e) => DhakaZone.fromJson(e)).toList(),
      );
}

class DhakaLocationsResponse {
  final List<DhakaCorporation> corporations;
  final int wardCount;
  DhakaLocationsResponse({required this.corporations, required this.wardCount});

  factory DhakaLocationsResponse.fromJson(Map<String, dynamic> j) {
    final data = j['data'] ?? j; // allow either wrapped or direct
    final corps = (data['corporations'] as List).map((e) => DhakaCorporation.fromJson(e)).toList();
    final wardCount = (data['meta']?['wardCount'] ?? 0) as int;
    return DhakaLocationsResponse(corporations: corps, wardCount: wardCount);
  }
}

final dhakaLocationsProvider = FutureProvider.family<DhakaLocationsResponse, String>((ref, lang) async {
  final uri = Uri.parse('${ApiConfig.host}/api/v1/locations/dhaka?lang=$lang');
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('Failed to load Dhaka locations: ${res.statusCode}');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DhakaLocationsResponse.fromJson(map);
});

// Helper: Dhaka District code in Furtail seed data
bool isDhakaDistrictCode(String? districtCode) => districtCode == 'DIS-47';
