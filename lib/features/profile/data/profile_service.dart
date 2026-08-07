import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:furtail_app/core/auth/auth_interceptor.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/auth/session_recovery.dart';
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
  final CentralAuthApi _centralAuthApi = CentralAuthApi();

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
        throw Exception('uploadMedia requires either (file) OR (bytes + filename).');
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

  /// Same as [uploadMedia] but reports upload progress and supports
  /// cancellation, for independent avatar/cover upload UI.
  Future<int> uploadMediaWithProgress({
    required File file,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final id = await _client.multipartPostTyped<int?>(
      url: '${ApiConfig.apiV1}/media/upload',
      files: [ApiMultipartFilePart(fieldName: 'file', file: file)],
      onSendProgress: onProgress,
      cancelToken: cancelToken,
      parse: (decoded) {
        final body = _normalizeResponse(decoded);
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : null;
        return int.tryParse(data?['id']?.toString() ?? '');
      },
    );
    if (id == null) {
      throw Exception('Upload succeeded but media id not found in response.');
    }
    return id;
  }

  /// Update own profile (PATCH /user/me).
  /// Payload keys supported by backend:
  /// displayName, username, bio, visibility, showEmail, showPhone,
  /// avatarMediaId, coverMediaId, education, placeLive, from,
  /// profileType, workStatus, religiousStatus, gender, birthdate,
  /// maritalStatus
  Future<UserProfileModel> updateProfile(Map<String, dynamic> payload) async {
    final response = await _client.patch('${ApiConfig.apiV1}/user/me', payload, auth: true);

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

  /// True if [error] is a Central-Auth session failure that a token
  /// refresh could plausibly fix — any 401 from a direct Central Auth
  /// call (unlike Furtail-routed calls, Central Auth's own protected
  /// routes have no other 401 source to conflate with).
  bool _isCentralAuthSessionExpired(Object error) =>
      error is CentralAuthException && error.isUnauthorized;

  Future<T> _withSessionRecovery<T>(Future<T> Function(String accessToken) call) {
    return SessionRecovery.instance.run(call, isSessionExpired: _isCentralAuthSessionExpired);
  }

  Future<CentralAuthUser> getAccountIdentity() {
    return _withSessionRecovery((token) => _centralAuthApi.me(token));
  }

  /// PATCH /auth/me — firstName, lastName, dateOfBirth, displayName.
  /// Never sends DOB to the Furtail profile endpoint (updateProfile above).
  Future<CentralAuthUser> updateIdentity({
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
  }) {
    return _withSessionRecovery(
      (token) => _centralAuthApi.updateProfile(
        accessToken: token,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth,
      ),
    );
  }

  Future<void> requestEmailVerification(String email) {
    return _withSessionRecovery(
      (token) => _centralAuthApi.requestEmailVerification(accessToken: token, email: email),
    );
  }

  Future<void> requestPhoneChange(String phone) {
    return _withSessionRecovery(
      (token) => _centralAuthApi.requestPhoneChange(accessToken: token, phone: phone),
    );
  }

  Future<void> confirmPhoneChange(String code) {
    return _withSessionRecovery(
      (token) => _centralAuthApi.confirmPhoneChange(accessToken: token, code: code),
    );
  }

  Future<List<CentralAuthSession>> listSessions() {
    return _withSessionRecovery((token) => _centralAuthApi.listSessions(token));
  }

  Future<void> revokeSession(String sessionId) {
    return _withSessionRecovery((token) => _centralAuthApi.revokeSession(token, sessionId));
  }

  Future<void> logoutAllOtherDevices() {
    return _withSessionRecovery((token) => _centralAuthApi.logoutAllOtherDevices(token));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _withSessionRecovery(
      (token) => _centralAuthApi.changePassword(
        accessToken: token,
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ),
    );
  }

  Future<void> deactivateAccount({String? password}) {
    return _withSessionRecovery(
      (token) => _centralAuthApi.deactivateAccount(accessToken: token, password: password),
    );
  }

  Future<void> deleteAccount({String? password}) {
    return _withSessionRecovery(
      (token) => _centralAuthApi.deleteAccount(accessToken: token, password: password),
    );
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final response = await _client.get(
      '${ApiConfig.apiV1}/user/me/notification-preferences',
      auth: true,
    );
    final body = _normalizeResponse(response);
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(Map<String, dynamic> payload) async {
    final response = await _client.patch(
      '${ApiConfig.apiV1}/user/me/notification-preferences',
      payload,
      auth: true,
    );
    final body = _normalizeResponse(response);
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<UserProfileModel> _getProfileAt(String url) async {
    final response = await _client.get(url, auth: true);
    final data = _normalizeResponse(response);

    if (data is Map && data['data'] is Map) {
      final model = UserProfileModel.fromApi(Map<String, dynamic>.from(data['data'] as Map));
      return await _applyBust(model);
    }

    final model = UserProfileModel.fromApi(Map<String, dynamic>.from(data as Map));
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
