import 'deep_link_config.dart';
import 'deep_link_target.dart';

/// Parses `bpa://` and HTTPS universal/app links into [DeepLinkTarget].
abstract final class DeepLinkParser {
  static const _typeAliases = <String, DeepLinkKind>{
    'campaign': DeepLinkKind.campaign,
    'campaigns': DeepLinkKind.campaign,
    'post': DeepLinkKind.post,
    'posts': DeepLinkKind.post,
    'pet': DeepLinkKind.pet,
    'pets': DeepLinkKind.pet,
    'fundraising': DeepLinkKind.fundraising,
    'fundraise': DeepLinkKind.fundraising,
    'donation': DeepLinkKind.fundraising,
    'profile': DeepLinkKind.profile,
    'user': DeepLinkKind.profile,
  };

  /// Returns null when URI is not a recognized BPA deep link.
  static DeepLinkTarget? parse(Uri uri) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == DeepLinkConfig.customScheme && uri.host.isNotEmpty) {
      segs.insert(0, uri.host);
    }

    final fromSegments = _fromSegments(segs);
    if (fromSegments != null) return fromSegments;

    final normalized = _normalize(uri);
    if (normalized == null) return null;
    final (type, id) = normalized;
    final kind = _typeAliases[type.toLowerCase()];
    if (kind == null || id.isEmpty) return null;
    return DeepLinkTarget(kind: kind, id: id);
  }

  static DeepLinkTarget? parseString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('bpa://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('http://')) {
      return parse(Uri.parse(trimmed));
    }

    if (trimmed.startsWith('/')) {
      return parse(Uri(path: trimmed));
    }

    final parts = trimmed.split('/').where((p) => p.isNotEmpty).toList();
    return _fromSegments(parts);
  }

  static DeepLinkTarget? _fromSegments(List<String> parts) {
    if (parts.length >= 3 &&
        parts[0].toLowerCase() == 'campaign' &&
        parts[1].toLowerCase() == 'detail') {
      return DeepLinkTarget(kind: DeepLinkKind.campaignDetail, id: parts[2]);
    }
    if (parts.length >= 3 &&
        parts[0].toLowerCase() == 'campaign' &&
        parts[1].toLowerCase() == 'book') {
      return DeepLinkTarget(kind: DeepLinkKind.campaignDetail, id: parts[2]);
    }
    if (parts.length >= 2) {
      final kind = _typeAliases[parts[0].toLowerCase()];
      if (kind != null) {
        if (kind == DeepLinkKind.campaign && !RegExp(r'^\d+$').hasMatch(parts[1])) {
          return DeepLinkTarget(kind: DeepLinkKind.campaignDetail, id: parts[1]);
        }
        return DeepLinkTarget(kind: kind, id: parts[1]);
      }
    }
    return null;
  }

  static (String type, String id)? _normalize(Uri uri) {
    if (uri.scheme == DeepLinkConfig.customScheme) {
      final type = uri.host;
      if (type.isEmpty) {
        if (uri.pathSegments.length >= 2) {
          return (uri.pathSegments[0], uri.pathSegments[1]);
        }
        return null;
      }
      final id = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : uri.path.replaceFirst('/', '');
      if (id.isEmpty) return null;
      return (type, id);
    }

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (!DeepLinkConfig.isAllowedHost(uri.host)) return null;
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.length >= 2) return (segs[0], segs[1]);
      return null;
    }

    if (uri.scheme.isEmpty && uri.pathSegments.length >= 2) {
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      return (segs[0], segs[1]);
    }

    return null;
  }
}
