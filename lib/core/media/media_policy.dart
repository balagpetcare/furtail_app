class MediaPolicy {
  // ---- Upload limits (bytes) ----
  static const int maxImageBytes = 8 * 1024 * 1024; // 8MB
  static const int maxVideoBytes = 80 * 1024 * 1024; // 80MB
  static const int maxFileBytes = 20 * 1024 * 1024; // 20MB

  // ---- Image compression ----
  static const int imageMinWidth = 1280;
  static const int imageMinHeight = 1280;
  static const int imageQuality = 80; // 0-100
  static const int imageMaxSideServerHint = 1600; // aligns with API default

  // ---- Video compression (client-side) ----
  static const bool compressVideo = true;
  // If your video plugin supports presets, keep it medium by default.
}
