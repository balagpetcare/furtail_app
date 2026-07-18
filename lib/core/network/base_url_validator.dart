/// Shared fail-fast validator for the app's two API base URLs (Furtail API
/// and Central Auth API). Both `ApiConfig` and `CentralAuthConfig` build a
/// host string at compile/runtime from dart-defines with a platform
/// fallback — this catches the case where that host ends up empty or
/// missing a scheme/authority (e.g. a malformed `--dart-define`) at startup,
/// instead of letting Dio fail deep inside a request with an opaque
/// "No host specified in URI" error.
bool isValidHttpBaseUrl(String url) {
  if (url.trim().isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  return true;
}

/// Throws a [StateError] with [hint] if [url] is not a valid absolute
/// http(s) base URL.
void assertValidBaseUrl({
  required String label,
  required String url,
  required String hint,
}) {
  if (!isValidHttpBaseUrl(url)) {
    throw StateError(
      'Invalid $label configuration: "$url" is not an absolute http(s) URL. $hint',
    );
  }
}
