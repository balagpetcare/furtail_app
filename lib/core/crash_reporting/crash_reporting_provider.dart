import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bpa_crashlytics_provider_observer.dart';
import 'crash_reporting_service.dart';

final crashReportingServiceProvider = Provider<CrashReportingService>(
  (ref) => CrashReportingService.instance,
);

final crashlyticsProviderObserverProvider = Provider<BpaCrashlyticsProviderObserver>(
  (ref) => BpaCrashlyticsProviderObserver(),
);
