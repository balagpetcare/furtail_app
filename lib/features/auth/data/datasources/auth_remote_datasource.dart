import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bpa_app/core/network/api_endpoints.dart';

class AuthRemoteDataSource {
  bool _isEmail(String s) => s.contains('@');
  // Accept digits-only OR common phone formats like +88017..., 017..., spaces/dashes
  bool _isPhone(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return false;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    // basic sanity: at least 8 digits and not absurdly long
    return digits.length >= 8 && digits.length <= 15;
  }

  Map<String, dynamic> _safeJsonMap(http.Response res) {
    final ct = (res.headers['content-type'] ?? '').toLowerCase();
    if (!ct.contains('application/json')) {
      // Backend should return JSON. If it doesn't, show a helpful error.
      throw Exception(
        'Server did not return JSON (content-type: $ct). Body: ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Invalid JSON response');
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final id = identifier.trim();
    final body = <String, dynamic>{
      'password': password,
      // Send ONLY the relevant identifier field; do not send empty strings.
      if (_isEmail(id)) 'email': id.toLowerCase(),
      if (_isPhone(id)) 'phone': id.replaceAll(RegExp(r'\D'), ''),
    };

    final uri = Uri.parse(ApiEndpoints.login());

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final data = _safeJsonMap(res);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }

    final message = data['message']?.toString() ?? 'Login failed';
    throw Exception(message);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String identifier,
    required String password,
  }) async {
    final uri = Uri.parse(ApiEndpoints.register());

    final id = identifier.trim();
    final body = <String, dynamic>{
      'name': name,
      'password': password,
      // ✅ backend supports email OR phone
      'email': _isEmail(id) ? id : null,
      'phone': _isPhone(id) ? id : null,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final data = _safeJsonMap(res);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }

    final message = data['message']?.toString() ?? 'Registration failed';
    throw Exception(message);
  }


  // -----------------------------
  // Social Login
  // -----------------------------

  Future<Map<String, dynamic>> loginWithGoogle({required String idToken}) async {
    final uri = Uri.parse(ApiEndpoints.socialGoogle());

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    final data = _safeJsonMap(res);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }

    final message = data['message']?.toString() ?? 'Google login failed';
    throw Exception(message);
  }

  Future<Map<String, dynamic>> loginWithFacebook({
    required String accessToken,
  }) async {
    final uri = Uri.parse(ApiEndpoints.socialFacebook());

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'accessToken': accessToken}),
    );

    final data = _safeJsonMap(res);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }

    final message = data['message']?.toString() ?? 'Facebook login failed';
    throw Exception(message);
  }

}
