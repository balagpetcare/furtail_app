import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/auth_gate.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/logout_reset.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/features/auth/presentation/screens/login_screen.dart';
import 'package:furtail_app/features/home/presentation/screens/furtail_home_screen.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _store.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _store.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _store[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_store);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }
}

/// Real [AuthController] except for [bootstrap], which normally performs a live
/// `GET /auth/me` (plus a Central Auth bootstrap fetch). Under `flutter test`
/// those requests never resolve, so every test in this file used to sit for the
/// full 10-minute timeout. Session restore is decided from secure storage only,
/// which is all these navigation tests actually need.
class _OfflineBootstrapAuthController extends AuthController {
  _OfflineBootstrapAuthController(
    SecureStorageService storage,
    CentralAuthApi centralAuthApi,
    ApiClient apiClient,
  ) : _storage = storage,
      super(storage, centralAuthApi, apiClient);

  final SecureStorageService _storage;

  @override
  Future<void> bootstrap() async {
    state = AuthState(
      status: await _storage.hasSession
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }
}

/// `AuthController.logout()` publishes the unauthenticated state first and only
/// then makes a best-effort remote revoke call. In production that ordering
/// means the UI never waits on the network, but under `flutter test` the real
/// request never resolves, so the awaited call hangs the test. A no-op stand-in
/// keeps the local-cleanup semantics while removing the network hop.
class _NoopCentralAuthApi implements CentralAuthApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

List<Override> _offlineBootstrapOverrides() => [
  authControllerProvider.overrideWith(
    (ref) => _OfflineBootstrapAuthController(
      ref.read(secureStorageServiceProvider),
      _NoopCentralAuthApi(),
      ref.read(apiClientProvider),
    ),
  ),
];

/// Bounded replacement for `pumpAndSettle`. The real [FurtailHomeScreen] runs
/// continuous animations (shimmer placeholders, media widgets), so
/// `pumpAndSettle` never reaches a quiescent frame here and every test in this
/// file used to hang for the full timeout. A few fixed frames are enough to
/// flush the auth-state rebuild and the post-frame route cleanup.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();

  group('Logout Navigator Crash', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'Logout from authenticated state returns to login without Navigator crash',
      (tester) async {
        final container = ProviderContainer(
          overrides: _offlineBootstrapOverrides(),
        );
        addTearDown(container.dispose);

        // Setup initial authenticated state
        final secureStorage = container.read(secureStorageServiceProvider);
        await secureStorage.saveTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
        );

        WidgetRef? capturedRef;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return AuthGate(authenticatedChild: FurtailHomeScreen());
                },
              ),
            ),
          ),
        );

        // Bootstrap auth state
        await container.read(authControllerProvider.notifier).bootstrap();
        await _settle(tester);

        expect(
          container.read(authControllerProvider).status,
          AuthStatus.authenticated,
        );

        // Perform logout
        expect(capturedRef, isNotNull);
        await resetSessionScopedState(capturedRef!);
        await _settle(tester);

        // Verify we're at login screen without crash
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.unauthenticated,
        );

        // Should see LoginScreen now
        expect(
          find.byType(LoginScreen),
          findsOneWidget,
          reason: 'Should be at login screen after logout',
        );
      },
    );

    testWidgets('Logout never tries to pop empty Navigator', (tester) async {
      WidgetRef? capturedRef;

      final container = ProviderContainer(
        overrides: _offlineBootstrapOverrides(),
      );
      addTearDown(container.dispose);

      // Setup
      final secureStorage = container.read(secureStorageServiceProvider);
      await secureStorage.saveTokens(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
      );

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorKey: navigatorKey,
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return AuthGate(authenticatedChild: FurtailHomeScreen());
              },
            ),
          ),
        ),
      );

      await container.read(authControllerProvider.notifier).bootstrap();
      await _settle(tester);

      // Logout should not cause Navigator._history.isEmpty assertion
      expect(capturedRef, isNotNull);
      await resetSessionScopedState(capturedRef!);
      await _settle(tester);

      // If we get here without a crash, the test passed
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    testWidgets('Can log back in after logout without Navigator errors', (
      tester,
    ) async {
      late WidgetRef capturedRef;

      final container = ProviderContainer(
        overrides: _offlineBootstrapOverrides(),
      );
      addTearDown(container.dispose);

      // Setup initial state
      final secureStorage = container.read(secureStorageServiceProvider);
      await secureStorage.saveTokens(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return AuthGate(authenticatedChild: FurtailHomeScreen());
              },
            ),
          ),
        ),
      );

      await container.read(authControllerProvider.notifier).bootstrap();
      await _settle(tester);

      // Logout
      await resetSessionScopedState(capturedRef);
      await _settle(tester);

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );

      // Try to log back in by setting tokens again
      await secureStorage.saveTokens(
        accessToken: 'new-token',
        refreshToken: 'new-refresh',
      );

      // Bootstrap again - should not crash
      await container.read(authControllerProvider.notifier).bootstrap();
      await _settle(tester);

      // Should transition to authenticated without Navigator errors
      expect(
        find.byType(FurtailHomeScreen),
        findsOneWidget,
        reason: 'Should show authenticated screen after login',
      );
    });
  });
}
