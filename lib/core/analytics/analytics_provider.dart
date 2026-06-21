import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';

/// Global analytics service (Firebase Analytics).
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService.instance,
);
