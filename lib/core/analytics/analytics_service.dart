import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../crash_reporting/crash_reporting_service.dart';
import '../storage/local_storage.dart';
import 'analytics_events.dart';

/// Central Firebase Analytics facade. Safe no-op when Firebase is unavailable.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _initialized = false;

  bool get isEnabled => _initialized && _analytics != null;

  FirebaseAnalytics? get analytics => _analytics;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[AnalyticsService] initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AnalyticsService] init skipped: $e');
      }
      _analytics = null;
      _initialized = true;
    }
  }

  Future<void> setUserIdFromStorage() async {
    final id = await LocalStorage.getUserId();
    if (id != null) await setUserId(id);
  }

  Future<void> setUserId(int? userId) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.setUserId(id: userId?.toString());
    } catch (_) {}
  }

  Future<void> clearUserId() async {
    await setUserId(null);
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      final params = _sanitize(parameters);
      await a.logEvent(name: name, parameters: params);
      if (kDebugMode) {
        debugPrint('[Analytics] $name ${params ?? {}}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] logEvent failed ($name): $e');
      }
    }
  }

  // --- Catalog helpers ---

  Future<void> logLogin({String method = AnalyticsAuthMethod.email}) async {
    final a = _analytics;
    if (a != null) {
      try {
        await a.logLogin(loginMethod: method);
      } catch (_) {}
    }
    await logEvent(AnalyticsEvents.login, parameters: {AnalyticsEvents.method: method});
    await setUserIdFromStorage();
    await CrashReportingService.instance.setUserIdFromStorage();
  }

  Future<void> logRegistration({String method = AnalyticsAuthMethod.email}) async {
    final a = _analytics;
    if (a != null) {
      try {
        await a.logSignUp(signUpMethod: method);
      } catch (_) {}
    }
    await logEvent(AnalyticsEvents.registration, parameters: {AnalyticsEvents.method: method});
  }

  Future<void> logPetCreated({required int petId, String? species}) async {
    await logEvent(
      AnalyticsEvents.petCreated,
      parameters: {
        AnalyticsEvents.petId: petId,
        if (species != null && species.isNotEmpty) 'species': species,
      },
    );
  }

  Future<void> logCampaignRegistered({int? importedCount}) async {
    await logEvent(
      AnalyticsEvents.campaignRegistered,
      parameters: {
        if (importedCount != null) AnalyticsEvents.importedCount: importedCount,
      },
    );
  }

  Future<void> logDonationMade({
    required int campaignId,
    required num amount,
    String currency = 'BDT',
  }) async {
    await logEvent(
      AnalyticsEvents.donationMade,
      parameters: {
        AnalyticsEvents.campaignId: campaignId,
        AnalyticsEvents.amount: amount,
        AnalyticsEvents.currency: currency,
      },
    );
  }

  Future<void> logPostCreated({required String postType, int? postId}) async {
    await logEvent(
      AnalyticsEvents.postCreated,
      parameters: {
        AnalyticsEvents.postType: postType,
        if (postId != null) AnalyticsEvents.postId: postId,
      },
    );
  }

  Future<void> logCommentCreated({
    required int postId,
    int? commentId,
    bool isReply = false,
  }) async {
    await logEvent(
      AnalyticsEvents.commentCreated,
      parameters: {
        AnalyticsEvents.postId: postId,
        if (commentId != null) AnalyticsEvents.commentId: commentId,
        AnalyticsEvents.isReply: isReply,
      },
    );
  }

  Future<void> logProfileViewed({
    required int profileUserId,
    String source = 'in_app',
  }) async {
    await logEvent(
      AnalyticsEvents.profileViewed,
      parameters: {
        AnalyticsEvents.profileUserId: profileUserId,
        AnalyticsEvents.source: source,
      },
    );
  }

  Future<void> logQrViewed({String source = 'in_app'}) async {
    await logEvent(
      AnalyticsEvents.qrViewed,
      parameters: {AnalyticsEvents.source: source},
    );
  }

  Future<void> logCertificateViewed({bool hasToken = true}) async {
    await logEvent(
      AnalyticsEvents.certificateViewed,
      parameters: {AnalyticsEvents.hasToken: hasToken},
    );
  }

  Map<String, Object>? _sanitize(Map<String, Object?>? raw) {
    if (raw == null || raw.isEmpty) return null;
    final out = <String, Object>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is String || v is num || v is bool) {
        out[e.key] = v;
      } else {
        out[e.key] = v.toString();
      }
    }
    return out.isEmpty ? null : out;
  }
}
