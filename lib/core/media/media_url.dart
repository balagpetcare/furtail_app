import 'package:bpa_app/core/config/app_config.dart';

/// Normalizes media URLs coming from the backend/DB.
///
/// Why:
/// - Backend may return MinIO URLs with `localhost:9000` (works only on same PC).
/// - Mobile/real devices need LAN IP (set via --dart-define=MEDIA_BASE_URL).
/// - Some older rows may store relative paths.
///
/// Rules:
/// - Absolute http(s) URLs: keep, but rewrite host to MEDIA_BASE_URL if host is localhost/127.0.0.1/10.0.2.2 or contains docker-internal names.
/// - Relative paths: prefix with MEDIA_BASE_URL.
class MediaUrl {
  static String normalize(String raw) {
    final u = raw.trim();
    if (u.isEmpty) return u;

    final mediaBase = AppConfig.mediaBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (mediaBase.isEmpty) return u;

    // Relative path -> media base
    if (!(u.startsWith('http://') || u.startsWith('https://'))) {
      final path = u.startsWith('/') ? u.substring(1) : u;
      return '$mediaBase/$path';
    }

    // Absolute -> if it's pointing to localhost/emulator/docker, rewrite.
    try {
      final uri = Uri.parse(u);
      final host = (uri.host).toLowerCase();

      final looksLocal = host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '10.0.2.2' ||
          host.endsWith('.local') ||
          host.contains('bpa-storage') ||
          host.contains('minio');

      if (!looksLocal) return u;

      final baseUri = Uri.parse(mediaBase);
      return uri.replace(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: baseUri.hasPort ? baseUri.port : (uri.hasPort ? uri.port : null),
      ).toString();
    } catch (_) {
      return u;
    }
  }

  /// Adds a cache-busting query param so updated images reflect instantly.
  ///
  /// Example: https://.../avatar.jpg?t=1700000000000
  static String cacheBust(String url, int? ts) {
    if (ts == null || ts <= 0) return url;
    final u = url.trim();
    if (u.isEmpty || u.startsWith('file://')) return u;
    try {
      final uri = Uri.parse(u);
      final q = Map<String, String>.from(uri.queryParameters);
      q['t'] = ts.toString();
      return uri.replace(queryParameters: q).toString();
    } catch (_) {
      final sep = u.contains('?') ? '&' : '?';
      return '$u${sep}t=$ts';
    }
  }
}
