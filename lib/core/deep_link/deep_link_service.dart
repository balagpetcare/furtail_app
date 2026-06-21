import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../navigation/app_navigator.dart';
import 'deep_link_navigator.dart';
import 'deep_link_parser.dart';
import 'deep_link_target.dart';

/// Listens for custom scheme + universal/app links and routes in-app.
class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  bool _initialized = false;

  DeepLinkTarget? _pendingTarget;
  DeepLinkTarget? get pendingTarget => _pendingTarget;

  bool get isInitialized => _initialized;

  /// Call once after [MaterialApp] is mounted (navigator key attached).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _pendingTarget = DeepLinkParser.parse(initial);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DeepLinkService] getInitialLink: $e');
        debugPrint('$st');
      }
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      _onIncomingUri,
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('[DeepLinkService] stream error: $e');
          debugPrint('$st');
        }
      },
    );
  }

  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
    _initialized = false;
  }

  void _onIncomingUri(Uri uri) {
    handleUri(uri);
  }

  /// Parses and navigates. Returns true if handled.
  Future<bool> handleUri(Uri uri) async {
    final target = DeepLinkParser.parse(uri);
    if (target == null) return false;
    return navigateTo(target);
  }

  /// Handles string URLs from push payloads (`bpa://…`, `https://…`, `/post/1`).
  Future<bool> handleString(String raw) async {
    final target = DeepLinkParser.parseString(raw);
    if (target == null) return false;
    return navigateTo(target);
  }

  Future<bool> navigateTo(DeepLinkTarget target) async {
    final nav = AppNavigator.state;
    if (nav == null) {
      _pendingTarget = target;
      if (kDebugMode) {
        debugPrint('[DeepLinkService] queued pending: $target');
      }
      return false;
    }
    _pendingTarget = null;
    return DeepLinkNavigator.navigate(nav, target);
  }

  /// Flushes [pendingTarget] or cold-start initial link after first frame.
  Future<bool> flushPending() async {
    if (_pendingTarget == null) return false;
    final target = _pendingTarget!;
    _pendingTarget = null;
    return navigateTo(target);
  }
}
