import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crash_reporting_service.dart';

/// Reports Riverpod provider failures to [CrashReportingService].
class FurtailCrashlyticsProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    CrashReportingService.instance.recordRiverpodError(
      providerName: provider.name ?? provider.runtimeType.toString(),
      error: error,
      stackTrace: stackTrace,
    );
    super.providerDidFail(provider, error, stackTrace, container);
  }
}
