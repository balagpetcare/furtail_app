/// Single canonical helper for joining a base URL and a path segment without
/// producing `//` (when `base` ends with `/` and `path` starts with `/`) or
/// missing the separator entirely (when neither has one).
///
/// Use this instead of ad hoc `'$base' + '$path'` / `'$base/$path'`
/// string-concatenation wherever a URL is assembled outside of Dio's own
/// `baseUrl` + relative-path resolution (which already handles this
/// correctly on its own and does not need this helper).
String joinUrl(String base, String path) {
  final trimmedBase = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  final trimmedPath = path.startsWith('/') ? path.substring(1) : path;
  if (trimmedPath.isEmpty) return trimmedBase;
  return '$trimmedBase/$trimmedPath';
}
