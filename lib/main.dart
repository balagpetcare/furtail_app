import 'core/storage/local_storage.dart';
import 'dart:async';
import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'app/router/app_router.dart';
import 'core/deep_link/deep_link_provider.dart';
import 'core/localization/locale_controller.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'core/accessibility/a11y_widgets.dart';
import 'core/analytics/analytics_service.dart';
import 'core/crash_reporting/furtail_crashlytics_provider_observer.dart';
import 'core/crash_reporting/crash_reporting_service.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'features/notifications/presentation/providers/notification_controller.dart';
import 'core/services/post_upload_manager.dart';
import 'core/media/furtail_cache_manager.dart' show VideoCacheService;
import 'core/network/api_config.dart';
import 'core/config/central_auth_config.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await firebaseMessagingBackgroundHandler(message);
}

void main() {
  CrashReportingService.instance.installGlobalHandlers();

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Fail fast on a broken API host configuration instead of letting Dio
    // throw "No host specified in URI" deep inside the first network call
    // (e.g. the post-login Furtail /auth/me profile fetch).
    ApiConfig.assertValid();
    CentralAuthConfig.assertValid();

    dev.log('[AppConfig] API_BASE_URL=${ApiConfig.apiV1}', name: 'AppConfig');
    dev.log(
      '[AppConfig] CENTRAL_AUTH_API_BASE_URL=${CentralAuthConfig.apiV1}',
      name: 'AppConfig',
    );
    await LocalStorage.migrateLegacyPreferences();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await AnalyticsService.instance.initialize();
      await CrashReportingService.instance.initialize();
    } catch (_) {
      // Firebase config placeholder — local notifications still work.
      await AnalyticsService.instance.initialize();
      await CrashReportingService.instance.initialize();
    }

    runApp(
      ProviderScope(
        observers: [FurtailCrashlyticsProviderObserver()],
        child: const FurtailApp(),
      ),
    );
  }, CrashReportingService.instance.recordZoneError);
}

class FurtailApp extends ConsumerStatefulWidget {
  const FurtailApp({super.key});

  @override
  ConsumerState<FurtailApp> createState() => _FurtailAppState();
}

class _FurtailAppState extends ConsumerState<FurtailApp> {
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
    try {
      PostUploadManager.instance.checkAndProcessPendingRetry();
    } catch (_) {}
    // Remove temp files left by video_compress from previous sessions.
    VideoCacheService.clearStaleTempFiles().ignore();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationControllerProvider);

    final localeAsync = ref.watch(localeControllerProvider);
    final locale = localeAsync.asData?.value;
    final requestedRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final initialRoute =
        requestedRoute.isEmpty || requestedRoute == Navigator.defaultRouteName
        ? Navigator.defaultRouteName
        : requestedRoute;

    return MaterialApp(
      navigatorKey: AppNavigator.key,
      debugShowCheckedModeBanner: false,
      builder: AppAccessibilityBuilder.wrap,
      title: 'Furtail',
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
      initialRoute: initialRoute,
    );
  }
}
