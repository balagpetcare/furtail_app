import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deep_link_service.dart';

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService();
  ref.onDispose(service.dispose);
  return service;
});
