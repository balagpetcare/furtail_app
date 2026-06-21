/// Deep link hosts and scheme configuration.
abstract final class DeepLinkConfig {
  static const String customScheme = 'furtail';

  /// HTTPS hosts allowed for Universal / App Links (override via dart-define).
  static const String universalLinkHost = String.fromEnvironment(
    'DEEP_LINK_HOST',
    defaultValue: 'app.furtail.global',
  );

  static const List<String> defaultAllowedHosts = [
    'app.furtail.global',
    'www.furtail.global',
    'furtail.global',
  ];

  static List<String> get allowedHosts {
    const extra = String.fromEnvironment('DEEP_LINK_HOSTS', defaultValue: '');
    final fromEnv = extra
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty);
    return {
      universalLinkHost.toLowerCase(),
      ...defaultAllowedHosts.map((h) => h.toLowerCase()),
      ...fromEnv,
    }.toList();
  }

  static bool isAllowedHost(String? host) {
    if (host == null || host.isEmpty) return false;
    final h = host.toLowerCase();
    return allowedHosts.any((allowed) => h == allowed || h.endsWith('.$allowed'));
  }

  /// Example universal link: https://app.furtail.global/campaign/42
  static Uri exampleUniversal(String type, String id) =>
      Uri.parse('https://$universalLinkHost/$type/$id');

  static Uri exampleCustom(String type, String id) =>
      Uri.parse('$customScheme://$type/$id');
}
