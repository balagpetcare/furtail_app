import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:furtail_app/features/settings/data/models/media_upload_settings.dart';

/// App-wide media quality preference, derived from the Settings > Media &
/// Storage "Upload Quality" control. `auto` (the default) leaves each
/// call site's own policy untouched; `dataSaver` forces conservative
/// (no-autoplay) behavior; `high` allows autoplay even on cellular.
enum MediaQualityPreference { dataSaver, auto, high }

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

  /// Synced from `MediaUploadSettings.uploadQuality` (Settings > Media &
  /// Storage) — see `MediaUploadSettingsNotifier` in settings_providers.dart.
  /// Layered on top of [playOneByOneWifiOnly] rather than replacing it:
  /// `dataSaver` forces conservative (no autoplay) behavior even on Wi-Fi;
  /// `high` allows autoplay even on cellular; `auto` (the default) defers
  /// entirely to the existing Wi-Fi-only toggle, so nothing changes for a
  /// user who hasn't touched the Upload Quality setting.
  MediaQualityPreference autoplayQualityPreference =
      MediaQualityPreference.auto;

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
    playOneByOneWifiOnly.value =
        _prefs?.getBool(_kPrefOneByOneWifiOnly) ?? true;

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

    // Reads UploadQuality directly from its own persisted storage rather
    // than through Riverpod: this controller (and the video widgets that
    // read it) can initialize before anything ever touches
    // mediaUploadSettingsProvider, e.g. on first app launch straight into
    // the feed. Whichever loads second (this, or the Settings screen's
    // provider) simply overwrites the other with the same persisted
    // value, so there's no conflict — just two independent readers of one
    // source of truth.
    try {
      final settings = await SettingsLocalDatasource()
          .loadMediaUploadSettings();
      setAutoplayQualityPreference(
        _toQualityPreference(settings.uploadQuality),
      );
    } catch (_) {
      // Leave the default (auto) — matches today's behavior if this fails.
    }
  }

  MediaQualityPreference _toQualityPreference(UploadQuality quality) {
    switch (quality) {
      case UploadQuality.dataSaver:
        return MediaQualityPreference.dataSaver;
      case UploadQuality.standard:
        return MediaQualityPreference.auto;
      case UploadQuality.high:
        return MediaQualityPreference.high;
    }
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

  /// Single authoritative setter for the app-wide quality preference.
  void setAutoplayQualityPreference(MediaQualityPreference preference) {
    autoplayQualityPreference = preference;
  }
}
