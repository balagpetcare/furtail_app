import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bpa_app/l10n/app_localizations.dart';
import 'app/router/app_router.dart';
import 'core/deep_link/deep_link_provider.dart';
import 'core/localization/locale_controller.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'core/accessibility/a11y_widgets.dart';
import 'core/analytics/analytics_service.dart';
import 'core/crash_reporting/bpa_crashlytics_provider_observer.dart';
import 'core/crash_reporting/crash_reporting_service.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'features/notifications/presentation/providers/notification_controller.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await AnalyticsService.instance.initialize();
    await CrashReportingService.instance.initialize();
  } catch (_) {
    // Firebase config placeholder — local notifications still work.
    await AnalyticsService.instance.initialize();
    await CrashReportingService.instance.initialize();
  }

  CrashReportingService.instance.installGlobalHandlers();

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          observers: [BpaCrashlyticsProviderObserver()],
          child: const BpaApp(),
        ),
      );
    },
    CrashReportingService.instance.recordZoneError,
  );
}

class BpaApp extends ConsumerStatefulWidget {
  const BpaApp({super.key});

  @override
  ConsumerState<BpaApp> createState() => _BpaAppState();
}

class _BpaAppState extends ConsumerState<BpaApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapServices());
  }

  Future<void> _bootstrapServices() async {
    ref.read(notificationControllerProvider);
    await ref.read(deepLinkServiceProvider).initialize();
    await ref.read(deepLinkServiceProvider).flushPending();
    final pending = await ref
        .read(notificationControllerProvider.notifier)
        .consumePendingTap();
    final actionUrl = pending?['actionUrl'] ?? pending?['action_url'];
    if (actionUrl != null && actionUrl.isNotEmpty) {
      await ref.read(deepLinkServiceProvider).handleString(actionUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationControllerProvider);

    final localeAsync = ref.watch(localeControllerProvider);
    final locale = localeAsync.asData?.value;

    return MaterialApp(
      navigatorKey: AppNavigator.key,
      debugShowCheckedModeBanner: false,
      builder: AppAccessibilityBuilder.wrap,
      title: 'BPA App',
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('bn')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.light,
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/',
    );
  }
}
