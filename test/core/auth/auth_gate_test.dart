import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/auth_gate.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/features/auth/presentation/screens/login_screen.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/services/api_client.dart';

class _StubAuthController extends AuthController {
  _StubAuthController(AuthState initial)
    : super(_NoopSecureStorage(), _NoopCentralAuthApi(), ApiClient()) {
    state = initial;
  }

  @override
  Future<void> bootstrap() async {
    // No-op: the test drives `state` directly instead of letting the real
    // bootstrap flow run against fakes.
  }
}

// Minimal no-op stand-ins; AuthGate only ever reads `authControllerProvider`
// (not these collaborators directly), but AuthController's constructor
// requires concrete instances.
class _NoopSecureStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoopCentralAuthApi implements CentralAuthApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pumpGate(WidgetTester tester, AuthState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => _StubAuthController(state),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AuthGate(authenticatedChild: Text('AUTHENTICATED_SHELL')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthGate', () {
    testWidgets('checkingSession (unknown) renders a branded loading '
        'screen, never a black/empty widget', (tester) async {
      await _pumpGate(tester, const AuthState(status: AuthStatus.unknown));

      expect(find.byType(Scaffold), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unauthenticated renders LoginScreen', (tester) async {
      await _pumpGate(
        tester,
        const AuthState(status: AuthStatus.unauthenticated),
      );

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('AUTHENTICATED_SHELL'), findsNothing);
    });

    testWidgets('authenticated renders the authenticated app shell', (
      tester,
    ) async {
      await _pumpGate(
        tester,
        const AuthState(status: AuthStatus.authenticated),
      );

      expect(find.text('AUTHENTICATED_SHELL'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('authError (bootstrapFailed) renders a safe retry/sign-in '
        'screen, never a black/empty widget', (tester) async {
      await _pumpGate(
        tester,
        const AuthState(
          status: AuthStatus.bootstrapFailed,
          lastError: 'Could not reach the server',
        ),
      );

      expect(find.byType(BootstrapRetryScreen), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('app startup with no session (unauthenticated) shows login', (
      tester,
    ) async {
      await _pumpGate(
        tester,
        const AuthState(status: AuthStatus.unauthenticated),
      );

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
