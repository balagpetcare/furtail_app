import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../storage/local_storage.dart';
import 'crash_source.dart';

/// Firebase Crashlytics facade — Flutter, async, Riverpod, and network errors.
class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService instance = CrashReportingService._();

  FirebaseCrashlytics? _crashlytics;
  bool _initialized = false;
  bool _handlersInstalled = false;

  bool get isEnabled => _initialized && _crashlytics != null;

  FirebaseCrashlytics? get crashlytics => _crashlytics;

  /// Call after [Firebase.initializeApp] (or alone; fails gracefully).
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _crashlytics = FirebaseCrashlytics.instance;
      await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[CrashReportingService] initialized (collection off in debug)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CrashReportingService] init skipped: $e');
      }
      _crashlytics = null;
      _initialized = true;
    }
  }

  /// Installs framework and platform error handlers (idempotent).
  void installGlobalHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    FlutterError.onError = (FlutterErrorDetails details) {
      recordFlutterError(details);
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(
        error,
        stack,
        source: CrashSource.async,
        fatal: true,
      );
      return true;
    };
  }

  /// Zone guard callback — use with [runZonedGuarded] in `main`.
  void recordZoneError(Object error, StackTrace stack) {
    recordError(error, stack, source: CrashSource.async, fatal: true);
  }

  Future<void> setUserIdFromStorage() async {
    final id = await LocalStorage.getUserId();
    await setUserId(id);
  }

  Future<void> setUserId(int? userId) async {
    final c = _crashlytics;
    if (c == null) return;
    try {
      await c.setUserIdentifier(userId?.toString() ?? '');
    } catch (_) {}
  }

  Future<void> clearUserId() async {
    await setUserId(null);
  }

  Future<void> log(String message) async {
    final c = _crashlytics;
    if (c == null) return;
    try {
      await c.log(message);
    } catch (_) {}
  }

  Future<void> setCustomKey(String key, Object value) async {
    final c = _crashlytics;
    if (c == null) return;
    try {
      await c.setCustomKey(key, value);
    } catch (_) {}
  }

  void recordFlutterError(FlutterErrorDetails details, {bool fatal = true}) {
    final c = _crashlytics;
    if (c == null) {
      if (kDebugMode) {
        debugPrint('[Crash] flutter: ${details.exceptionAsString()}');
      }
      return;
    }
    unawaited(_setSourceKey(CrashSource.flutter));
    try {
      if (fatal) {
        c.recordFlutterFatalError(details);
      } else {
        c.recordFlutterError(details);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Crash] recordFlutterError failed: $e');
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    CrashSource source = CrashSource.manual,
    bool fatal = false,
    String? reason,
  }) async {
    final c = _crashlytics;
    if (c == null) {
      if (kDebugMode) {
        debugPrint('[Crash] ${source.key}: $error');
      }
      return;
    }
    await _setSourceKey(source);
    if (reason != null) {
      await setCustomKey('error_reason', reason);
    }
    try {
      await c.recordError(
        error,
        stack,
        reason: reason ?? source.key,
        fatal: fatal,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Crash] recordError failed: $e');
    }
  }

  Future<void> recordRiverpodError({
    required String providerName,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    await setCustomKey('riverpod_provider', providerName);
    await recordError(
      error,
      stackTrace,
      source: CrashSource.riverpod,
      fatal: false,
      reason: 'riverpod_provider_fail',
    );
  }

  Future<void> recordNetworkError({
    required String method,
    required String url,
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
  }) async {
    final path = _sanitizeUrl(url);
    await setCustomKey('http_method', method);
    await setCustomKey('http_path', path);
    if (statusCode != null) {
      await setCustomKey('http_status', statusCode);
    }
    await recordError(
      error,
      stackTrace ?? StackTrace.current,
      source: CrashSource.network,
      fatal: false,
      reason: 'network_${statusCode ?? 'failure'}',
    );
  }

  Future<void> _setSourceKey(CrashSource source) async {
    await setCustomKey('crash_source', source.key);
  }

  String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.isNotEmpty ? uri.path : url;
    } catch (_) {
      return url;
    }
  }
}
