// Regression tests for the logout Navigator crash:
//
//   'package:flutter/src/widgets/navigator.dart':
//   Failed assertion: '_history.isNotEmpty': is not true.
//
// Two distinct defects are covered here:
//
//  1. FurtailAppDrawer._onTap used a bare `Navigator.pop(context)` to close the
//     drawer, and FurtailHomeScreen._handleDrawerSelect popped a *second* time.
//     Scaffold's drawer is backed by a LocalHistoryEntry, so once the drawer is
//     closed the extra pop removes the page route instead. On the first route
//     that empties Navigator._history and trips the assertion.
//
//  2. Logging out from a *pushed* protected route (settings, wallet, …) left
//     that route on the stack above AuthGate, so the user kept seeing
//     authenticated content and Android back walked into it.
//
// AuthGate is the single authoritative owner of post-logout navigation and uses
// popUntil((r) => r.isFirst), which can never empty the history.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/auth_gate.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/navigation/app_navigator.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/features/auth/presentation/screens/login_screen.dart';
import 'package:furtail_app/features/home/presentation/screens/widgets/custom_drawer.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

/// Minimal stand-in for the authenticated app. Using the real home screen would
/// drag in networking; these tests are about route ownership, not home content.
class _FakeAuthenticatedApp extends StatelessWidget {
  const _FakeAuthenticatedApp();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AUTHENTICATED_HOME')));
  }
}

class _ProtectedScreen extends StatelessWidget {
  const _ProtectedScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('PROTECTED_SETTINGS')));
  }
}

// Minimal no-op stand-ins; AuthGate only ever reads `authControllerProvider`,
// but AuthController's constructor requires concrete instances.
class _NoopSecureStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoopCentralAuthApi implements CentralAuthApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Drives auth status directly so the tests stay free of secure storage,
/// networking, and the Central Auth API. Every method that would touch a
/// dependency is overridden, so the injected collaborators are never used.
class _FakeAuthController extends AuthController {
  _FakeAuthController()
    : super(_NoopSecureStorage(), _NoopCentralAuthApi(), ApiClient());

  int logoutCalls = 0;

  @override
  Future<void> bootstrap() async {}

  void authenticate() =>
      state = const AuthState(status: AuthStatus.authenticated);

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// The Logout tile sits at the bottom of a long drawer, below the fold on the
/// default 800x600 test surface. Rendering on a tall surface keeps the whole
/// drawer laid out so the tile can be tapped without scroll gymnastics.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('drawer close never pops a page route', () {
    testWidgets(
      'tapping a drawer item on the first route leaves Navigator history intact',
      (tester) async {
        _useTallSurface(tester);
        final navigatorKey = GlobalKey<NavigatorState>();
        BPADrawerDestination? selected;
        final scaffoldKey = GlobalKey<ScaffoldState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            home: Scaffold(
              key: scaffoldKey,
              drawer: BPACustomDrawer(
                isLoggedIn: true,
                onSelect: (d) => selected = d,
              ),
              body: const Center(child: Text('AUTHENTICATED_HOME')),
            ),
          ),
        );

        scaffoldKey.currentState!.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();

        // The callback fired and the drawer closed...
        expect(selected, BPADrawerDestination.logout);
        expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);

        // ...but the page route itself must still be there. Before the fix the
        // pop removed it and emptied _history.
        expect(tester.takeException(), isNull);
        expect(find.text('AUTHENTICATED_HOME'), findsOneWidget);
        expect(navigatorKey.currentState!.canPop(), isFalse);
      },
    );

    testWidgets('rapid double-tap on logout does not pop the page route', (
      tester,
    ) async {
      _useTallSurface(tester);
      var selections = 0;
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: BPACustomDrawer(
              isLoggedIn: true,
              onSelect: (_) => selections++,
            ),
            body: const Center(child: Text('AUTHENTICATED_HOME')),
          ),
        ),
      );

      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Two taps before the close animation has run to completion.
      final logout = find.text('Logout');
      await tester.tap(logout, warnIfMissed: false);
      await tester.tap(logout, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('AUTHENTICATED_HOME'), findsOneWidget);
      expect(selections, greaterThanOrEqualTo(1));
    });
  });

  group('AuthGate owns post-logout navigation', () {
    late _FakeAuthController auth;
    late ProviderContainer container;

    Future<void> pumpApp(WidgetTester tester) async {
      auth = _FakeAuthController();
      container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith((ref) => auth)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: AppNavigator.key,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AuthGate(authenticatedChild: _FakeAuthenticatedApp()),
          ),
        ),
      );
      auth.authenticate();
      await tester.pumpAndSettle();
      expect(find.text('AUTHENTICATED_HOME'), findsOneWidget);
    }

    testWidgets('logout from the main authenticated screen shows login', (
      tester,
    ) async {
      await pumpApp(tester);

      await auth.logout();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('AUTHENTICATED_HOME'), findsNothing);
      expect(AppNavigator.state!.canPop(), isFalse);
    });

    testWidgets('logout from a pushed protected route discards that route', (
      tester,
    ) async {
      await pumpApp(tester);

      AppNavigator.state!.push(
        MaterialPageRoute<void>(builder: (_) => const _ProtectedScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('PROTECTED_SETTINGS'), findsOneWidget);
      expect(AppNavigator.state!.canPop(), isTrue);

      await auth.logout();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('PROTECTED_SETTINGS'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);

      // Android back must not reopen authenticated content.
      expect(AppNavigator.state!.canPop(), isFalse);
    });

    testWidgets(
      'logout with a confirmation dialog still open closes it safely',
      (tester) async {
        await pumpApp(tester);

        AppNavigator.state!.push(
          MaterialPageRoute<void>(builder: (_) => const _ProtectedScreen()),
        );
        await tester.pumpAndSettle();

        showDialog<void>(
          context: AppNavigator.context!,
          builder: (_) => const AlertDialog(content: Text('CONFIRM_LOGOUT')),
        );
        await tester.pumpAndSettle();
        expect(find.text('CONFIRM_LOGOUT'), findsOneWidget);

        await auth.logout();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('CONFIRM_LOGOUT'), findsNothing);
        expect(find.text('PROTECTED_SETTINGS'), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(AppNavigator.state!.canPop(), isFalse);
      },
    );

    testWidgets('deeply nested protected routes are all discarded', (
      tester,
    ) async {
      await pumpApp(tester);

      for (var i = 0; i < 4; i++) {
        AppNavigator.state!.push(
          MaterialPageRoute<void>(builder: (_) => const _ProtectedScreen()),
        );
      }
      await tester.pumpAndSettle();

      await auth.logout();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('PROTECTED_SETTINGS'), findsNothing);
      expect(AppNavigator.state!.canPop(), isFalse);
    });

    testWidgets('repeated unauthenticated emissions produce one login route', (
      tester,
    ) async {
      await pumpApp(tester);

      AppNavigator.state!.push(
        MaterialPageRoute<void>(builder: (_) => const _ProtectedScreen()),
      );
      await tester.pumpAndSettle();

      // Concurrent logout: user tap + interceptor forceLogout + retry.
      await auth.logout();
      await auth.logout();
      await auth.logout();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(auth.logoutCalls, 3);
      // Exactly one login screen; no duplicate login routes were pushed.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(AppNavigator.state!.canPop(), isFalse);
    });

    testWidgets('logging back in after logout restores authenticated content', (
      tester,
    ) async {
      await pumpApp(tester);

      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      auth.authenticate();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('AUTHENTICATED_HOME'), findsOneWidget);
      expect(AppNavigator.state!.canPop(), isFalse);
    });
  });
}
