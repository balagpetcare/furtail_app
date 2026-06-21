import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_endpoints.dart';

class ReportService {
  static Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('token');
  }

  /// Submit a report to backend.
  /// type: POST | FUNDRAISING | USER | PET
  static Future<void> submit({
    required String type,
    required int targetId,
    required String reasonCode,
    String? details,
  }) async {
    final t = await _token();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };

    final body = jsonEncode({
      'type': type,
      'targetId': targetId,
      'reasonCode': reasonCode,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    });

    final res = await http.post(
      Uri.parse(ApiEndpoints.createReport()),
      headers: headers,
      body: body,
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Report failed (${res.statusCode}): ${res.body}');
    }
  }
}
