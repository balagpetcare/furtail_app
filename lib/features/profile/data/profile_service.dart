import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bpa_app/core/network/api_config.dart';
import 'package:bpa_app/core/network/multipart_helper.dart';
import 'package:bpa_app/core/media/media_url.dart';
import 'models/user_profile_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Profile related API calls.
/// Backend (Node API) routes used:
/// - GET    /api/v1/user/me
/// - PATCH  /api/v1/user/me
/// - POST   /api/v1/media/upload   (multipart field name: file)
class ProfileService {
  static const _kAvatarBustTs = 'avatarBustTs';
  static const _kCoverBustTs = 'coverBustTs';

  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString("token");
  }

  /// Upload a media file (avatar/cover/gallery etc).
  ///
  /// Supported calling styles (to stay compatible with older UI code):
  /// 1) uploadMedia(bytes: ..., filename: ...)
  /// 2) uploadMedia(file: File(...), type: "IMAGE"/"VIDEO")  // type is optional for backend
  ///
  /// Returns created media `id`.
  Future<int> uploadMedia({
    List<int>? bytes,
    String? filename,
    File? file,
    String? type, // kept for compatibility; backend detects mime itself
  }) async {
    // Ensure we have a file to upload
    File? realFile = file;
    if (realFile == null) {
      if (bytes == null || filename == null) {
        throw Exception("uploadMedia requires either (file) OR (bytes + filename).");
      }
      // write bytes to a temp file so we can send it via multipart
      final tmpDir = Directory.systemTemp.createTempSync("bpa_media_");
      realFile = File("${tmpDir.path}/$filename");
      await realFile.writeAsBytes(bytes, flush: true);
    }

    final token = await _token();
    if (token == null) throw Exception("Unauthorized. Please login again.");

    final uri = Uri.parse("${ApiConfig.apiV1}/media/upload");
    final req = http.MultipartRequest("POST", uri);
    req.headers["Authorization"] = "Bearer $token";

    final name = filename ?? realFile.path.split(Platform.pathSeparator).last;
    req.files.add(await http.MultipartFile.fromPath("file", realFile.path, filename: name));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(_friendlyError(res));
    }

    final body = jsonDecode(res.body);
    final data = body is Map ? body["data"] : null;
    final id = (data is Map) ? data["id"] : null;
    final parsed = int.tryParse(id?.toString() ?? "");
    if (parsed == null) {
      throw Exception("Upload succeeded but media id not found in response.");
    }
    return parsed;
  }

  /// Update own profile (PATCH /user/me).
  /// Payload keys supported by backend:
  /// displayName, username, bio, visibility, showEmail, showPhone,
  /// avatarMediaId, coverMediaId, email, phone
  Future<UserProfileModel> updateProfile(Map<String, dynamic> payload) async {
    final token = await _token();
    if (token == null) throw Exception("Unauthorized. Please login again.");

    final uri = Uri.parse("${ApiConfig.apiV1}/user/me");
    final res = await http.patch(
      uri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception(_friendlyError(res));
    }

    // ✅ Cache busting: when avatar/cover changes, store a timestamp so UI refreshes instantly.
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (payload.containsKey('avatarMediaId')) {
      await sp.setInt(_kAvatarBustTs, now);
    }
    if (payload.containsKey('coverMediaId')) {
      await sp.setInt(_kCoverBustTs, now);
    }

    final data = jsonDecode(res.body);
    // backend returns {success:true, data: {...profile...}}
    final root = (data is Map) ? data : <String, dynamic>{};
    final profile = root["data"];
    if (profile is Map) {
      final model = UserProfileModel.fromApi(Map<String, dynamic>.from(profile));
      return await _applyBust(model);
    }
    // fallback: some older versions returned the profile directly
    if (data is Map) {
      final model = UserProfileModel.fromApi(Map<String, dynamic>.from(data));
      return await _applyBust(model);
    }
    throw Exception("Unexpected response from server.");
  }

  Future<UserProfileModel> getProfile() async {
    final token = await _token();
    if (token == null) throw Exception("Unauthorized. Please login again.");

    // ✅ Main endpoint
    final uri = Uri.parse("${ApiConfig.apiV1}/user/me");

    final res = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );

    // Optional fallback if your server only has /user/profile
    if (res.statusCode == 404) {
      final fallback = await http.get(
        Uri.parse("${ApiConfig.apiV1}/user/profile"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (fallback.statusCode != 200) {
        throw Exception(_friendlyError(fallback));
      }
      final data = jsonDecode(fallback.body);
      final model = UserProfileModel.fromApi(data as Map<String, dynamic>);
      return await _applyBust(model);
    }

    if (res.statusCode != 200) {
      throw Exception(_friendlyError(res));
    }

    final data = jsonDecode(res.body);
    // backend returns {success:true, data: {...}}
    if (data is Map && data["data"] is Map) {
      final model = UserProfileModel.fromApi(Map<String, dynamic>.from(data["data"]));
      return await _applyBust(model);
    }
    final model = UserProfileModel.fromApi(data as Map<String, dynamic>);
    return await _applyBust(model);
  }

  Future<UserProfileModel> _applyBust(UserProfileModel model) async {
    final sp = await SharedPreferences.getInstance();
    final avatarTs = sp.getInt(_kAvatarBustTs);
    final coverTs = sp.getInt(_kCoverBustTs);
    return model.copyWith(
      photoUrl: MediaUrl.cacheBust(model.photoUrl ?? '', avatarTs),
      coverUrl: MediaUrl.cacheBust(model.coverUrl ?? '', coverTs),
    );
  }

  String _friendlyError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      final msg = (body is Map) ? body["message"]?.toString() : null;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    if (res.statusCode == 400) return "Bad request. Please check inputs.";
    if (res.statusCode == 401) return "Unauthorized. Please login again.";
    if (res.statusCode == 404) return "Not found.";
    return "Request failed (${res.statusCode}). Please try again.";
  }
Future<http.MultipartFile> _multipartFromAnyFile(dynamic file) async {
  // On some real Android devices the picker can return content:// URIs.
  // http.MultipartFile.fromPath can't read those, so we fallback to bytes.
  if (file is XFile) {
    final bytes = await file.readAsBytes();
    final name = p.basename(file.name.isNotEmpty ? file.name : file.path);
    return http.MultipartFile.fromBytes('file', bytes, filename: name);
  }
  if (file is File) {
    final name = p.basename(file.path);
    return await http.MultipartFile.fromPath('file', file.path, filename: name);
  }
  throw Exception('Unsupported file type for upload: ${file.runtimeType}');
}
}