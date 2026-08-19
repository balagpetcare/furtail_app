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
import 'core/auth/auth_controller.dart';
import 'core/localization/locale_controller.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'core/accessibility/a11y_widgets.dart';
import 'core/analytics/analytics_service.dart';
import 'core/crash_reporting/furtail_crashlytics_provider_observer.dart';
import 'core/crash_reporting/crash_reporting_service.dart';
import 'core/config/app_config.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'features/notifications/presentation/providers/notification_controller.dart';
import 'features/social/presentation/providers/presence_providers.dart';
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

    dev.log('[AppConfig] API=${ApiConfig.apiV1}', name: 'AppConfig');
    dev.log('[AppConfig] SOCKET=${AppConfig.socketUrl}', name: 'AppConfig');
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

class _FurtailAppState extends ConsumerState<FurtailApp>
    with WidgetsBindingObserver {
  DateTime? _lastNotificationRefreshAt;
  ProviderSubscription<AuthState>? _authSubscription;
  int? _pushRegisteredForUserId;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  // Captured in initState — `ref` is not usable from dispose() once the
  // element starts unmounting (same pitfall as any ConsumerState), so the
  // reference dispose() needs has to be grabbed while `ref` is still live.
  late final HeartbeatController _heartbeatController;

  @override
  void initState() {
    super.initState();
    _heartbeatController = ref.read(heartbeatControllerProvider);
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = ref.listenManual(authControllerProvider, (
      previous,
      next,
    ) {
      final previousStatus = previous?.status;
      final currentStatus = next.status;
      if (currentStatus == AuthStatus.authenticated) {
        final userId = next.profile?.id;
        if (userId != null && userId != _pushRegisteredForUserId) {
          _pushRegisteredForUserId = userId;
          unawaited(
            ref
                .read(notificationControllerProvider.notifier)
                .registerPushAfterAuth(),
          );
        }
      } else if (previousStatus == AuthStatus.authenticated ||
          currentStatus == AuthStatus.unauthenticated ||
          currentStatus == AuthStatus.bootstrapFailed) {
        _pushRegisteredForUserId = null;
      }

      if (currentStatus == AuthStatus.authenticated) {
        if (_lifecycleState == AppLifecycleState.resumed) {
          ref.read(heartbeatControllerProvider).start();
        }
      } else if (previousStatus == AuthStatus.authenticated) {
        // Logout (or session loss) — clear active status immediately rather
        // than waiting out the Redis TTL.
        ref.read(heartbeatControllerProvider).stop(notifyOffline: true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapServices());
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _authSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatController.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lifecycleState = state;

    final isAuthenticated =
        ref.read(authControllerProvider).status == AuthStatus.authenticated;
    if (state == AppLifecycleState.resumed) {
      if (isAuthenticated) ref.read(heartbeatControllerProvider).start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (isAuthenticated) {
        ref.read(heartbeatControllerProvider).stop(notifyOffline: true);
      }
    }

    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (_lastNotificationRefreshAt != null &&
        now.difference(_lastNotificationRefreshAt!) <
            const Duration(seconds: 2)) {
      return;
    }
    _lastNotificationRefreshAt = now;

    unawaited(ref.read(notificationsUnreadCountProvider.future));
    final listState = ref.read(notificationsListProvider);
    if (listState.items.isNotEmpty ||
        listState.error != null ||
        listState.loading ||
        listState.loadingMore) {
      unawaited(ref.read(notificationsListProvider.notifier).load());
    }
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
