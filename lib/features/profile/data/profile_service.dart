import 'dart:io';

import 'package:furtail_app/core/auth/auth_interceptor.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/media/media_url.dart';
import 'models/user_profile_model.dart';

/// Profile related API calls.
/// Backend (Node API) routes used:
/// - GET    /api/v1/user/me
/// - PATCH  /api/v1/user/me
/// - POST   /api/v1/media/upload   (multipart field name: file)
class ProfileService {
  static const _kAvatarBustTs = 'avatarBustTs';
  static const _kCoverBustTs = 'coverBustTs';

  final ApiClient _client;

  ProfileService({ApiClient? client})
    : _client =
          client ??
          ApiClient(
            authInterceptor: AuthInterceptor(
              secureStorage: SecureStorageService(),
              centralAuthApi: CentralAuthApi(),
              onSessionExpired: () {},
            ),
          );

  dynamic _normalizeResponse(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{};
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
    File? realFile = file;
    if (realFile == null) {
      if (bytes == null || filename == null) {
        throw Exception(
          'uploadMedia requires either (file) OR (bytes + filename).',
        );
      }
      final tmpDir = Directory.systemTemp.createTempSync('bpa_media_');
      realFile = File('${tmpDir.path}/$filename');
      await realFile.writeAsBytes(bytes, flush: true);
    }

    final response = await _client.multipartPost(
      url: '${ApiConfig.apiV1}/media/upload',
      fieldName: 'file',
      filePath: realFile.path,
      auth: true,
    );
    final body = _normalizeResponse(response);
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body['data'];
    final id = (data is Map) ? data['id'] : null;
    final parsed = int.tryParse(id?.toString() ?? '');
    if (parsed == null) {
      throw Exception('Upload succeeded but media id not found in response.');
    }
    return parsed;
  }

  /// Update own profile (PATCH /user/me).
  /// Payload keys supported by backend:
  /// displayName, username, bio, visibility, showEmail, showPhone,
  /// avatarMediaId, coverMediaId, email, phone
  Future<UserProfileModel> updateProfile(Map<String, dynamic> payload) async {
    final response = await _client.patch(
      '${ApiConfig.apiV1}/user/me',
      payload,
      auth: true,
    );

    // Cache busting: when avatar/cover changes, store a timestamp so UI refreshes instantly.
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (payload.containsKey('avatarMediaId')) {
      await sp.setInt(_kAvatarBustTs, now);
    }
    if (payload.containsKey('coverMediaId')) {
      await sp.setInt(_kCoverBustTs, now);
    }

    final data = _normalizeResponse(response);
    final root = data['data'];
    if (root is Map) {
      final model = UserProfileModel.fromApi(Map<String, dynamic>.from(root));
      return await _applyBust(model);
    }
    if (data is Map) {
      final model = UserProfileModel.fromApi(Map<String, dynamic>.from(data));
      return await _applyBust(model);
    }
    throw Exception('Unexpected response from server.');
  }

  Future<UserProfileModel> getProfile() async {
    try {
      return await _getProfileAt('${ApiConfig.apiV1}/user/me');
    } on ApiClientException catch (e) {
      if (e.statusCode == 404) {
        return _getProfileAt('${ApiConfig.apiV1}/user/profile');
      }
      rethrow;
    }
  }

  Future<UserProfileModel> _getProfileAt(String url) async {
    final response = await _client.get(url, auth: true);
    final data = _normalizeResponse(response);

    if (data is Map && data['data'] is Map) {
      final model = UserProfileModel.fromApi(
        Map<String, dynamic>.from(data['data'] as Map),
      );
      return await _applyBust(model);
    }

    final model = UserProfileModel.fromApi(
      Map<String, dynamic>.from(data as Map),
    );
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
}
