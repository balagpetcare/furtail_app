import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central place for media playback rules across the app.
///
/// Features supported:
/// - Global mute/unmute for ALL videos
/// - "Play one by one (WiFi only)" policy switch
/// - Active inline-feed video id coordination (only one plays at a time)
///
/// NOTE: WiFi detection is intentionally not enforced here to keep this module
/// dependency-light. You can later wire connectivity_plus and gate autoplay.
class MediaPlaybackController {
  MediaPlaybackController._();

  static final MediaPlaybackController instance = MediaPlaybackController._();

  static const _kPrefMute = 'media_global_mute';
  static const _kPrefVolume = 'media_global_volume';
  static const _kPrefOneByOneWifiOnly = 'media_one_by_one_wifi_only';

  /// Global mute state.
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  /// Global volume (0.0 - 1.0). Used by feed + reels.
  final ValueNotifier<double> volume = ValueNotifier<double>(1.0);

  /// If true, only one video should play at a time (feed + reels).
  final ValueNotifier<bool> playOneByOneWifiOnly = ValueNotifier<bool>(true);

  /// The currently "active" inline-feed video post id.
  /// Players should pause themselves if they are not active.
  final ValueNotifier<int?> activeInlineVideoPostId = ValueNotifier<int?>(null);

  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  Future<void> ensureInitialized() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    isMuted.value = _prefs?.getBool(_kPrefMute) ?? false;
    volume.value = _prefs?.getDouble(_kPrefVolume) ?? 1.0;
    playOneByOneWifiOnly.value = _prefs?.getBool(_kPrefOneByOneWifiOnly) ?? true;

    // Persist changes.
    isMuted.addListener(() {
      _prefs?.setBool(_kPrefMute, isMuted.value);
    });
    volume.addListener(() {
      _prefs?.setDouble(_kPrefVolume, volume.value);
    });
    playOneByOneWifiOnly.addListener(() {
      _prefs?.setBool(_kPrefOneByOneWifiOnly, playOneByOneWifiOnly.value);
    });
  }

  void setVolume(double v) {
    final nv = v.clamp(0.0, 1.0).toDouble();
    volume.value = nv;
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
  }

  void setActiveInlineVideo(int? postId) {
    activeInlineVideoPostId.value = postId;
  }
}
