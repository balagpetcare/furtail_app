import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../core/network/api_endpoints.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post(ApiEndpoints.login(), {
      "email": email,
      "password": password,
    }, auth: false);

    // res must be a Map
    final Map<String, dynamic> map = Map<String, dynamic>.from(res);

    // Support both top-level and wrapped data
    final Map<String, dynamic>? data = (map["data"] is Map)
        ? Map<String, dynamic>.from(map["data"])
        : null;

    final String? token = (map["token"] ?? data?["token"])?.toString();
    final Map<String, dynamic>? user = (map["user"] is Map)
        ? Map<String, dynamic>.from(map["user"])
        : (data?["user"] is Map)
        ? Map<String, dynamic>.from(data?["user"])
        : null;

    // ✅ If backend returns success false, stop here
    final success = map["success"];
    if (success == false) {
      throw Exception(map["message"] ?? "Login failed");
    }

    if (token == null || token.isEmpty) {
      throw Exception("Login failed: token missing. Response: $map");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", token);

    if (user != null) {
      await prefs.setString("userName", (user["name"] ?? "User").toString());
      await prefs.setString("userEmail", (user["email"] ?? email).toString());

      // Store current user id (used for ownership checks like Edit/Delete post).
      try {
        final uid = user["id"] ?? user["userId"] ?? user["_id"];
        final parsed = (uid is num)
            ? uid.toInt()
            : int.tryParse(uid?.toString() ?? '');
        if (parsed != null) {
          await prefs.setInt('userId', parsed);
        }
      } catch (_) {}

      // Also store avatar url for comment composer & drawer.
      try {
        final profile = (user["profile"] is Map) ? Map<String, dynamic>.from(user["profile"]) : null;
        final avatarMedia = (profile != null && profile["avatarMedia"] is Map)
            ? Map<String, dynamic>.from(profile["avatarMedia"])
            : null;
        final avatarUrl = (avatarMedia?['url'] ?? '').toString().trim();
        if (avatarUrl.isNotEmpty) {
          await prefs.setString('avatarUrl', avatarUrl);
        }
      } catch (_) {}
    }

    return map;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
  }) async {
    final res = await _client.post(ApiEndpoints.register(), {
      "name": name,
      "email": email,
      "password": password,
      "phone": phone,
      "address": address,
    }, auth: false);

    return Map<String, dynamic>.from(res);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("userName");
    await prefs.remove("userEmail");
    await prefs.remove("userId");
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }
}
