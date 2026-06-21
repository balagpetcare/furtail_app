import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'furtail_crashlytics_provider_observer.dart';
import 'crash_reporting_service.dart';

final crashReportingServiceProvider = Provider<CrashReportingService>(
  (ref) => CrashReportingService.instance,
);

final crashlyticsProviderObserverProvider = Provider<FurtailCrashlyticsProviderObserver>(
  (ref) => FurtailCrashlyticsProviderObserver(),
);
