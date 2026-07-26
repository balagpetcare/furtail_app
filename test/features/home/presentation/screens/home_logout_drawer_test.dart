import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/auth_gate.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/config/policy_features_provider.dart';
import 'package:furtail_app/features/auth/presentation/screens/login_screen.dart';
import 'package:furtail_app/features/home/presentation/screens/furtail_home_screen.dart';
import 'package:furtail_app/features/notifications/presentation/providers/notification_controller.dart';
import 'package:furtail_app/features/settings/data/repositories/settings_repository.dart';
import 'package:furtail_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {
    'central_access_token': 'test-access-token',
    'central_refresh_token': 'test-refresh-token',
  };

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

class _FakeAuthController extends AuthController {
  bool logoutCalled = false;

  _FakeAuthController()
    : super(_NoopSecureStorage(), _NoopCentralAuthApi(), _NoopApiClient()) {
    state = const AuthState(status: AuthStatus.authenticated);
  }

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> logout() async {
    logoutCalled = true;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

class _NoopSecureStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoopCentralAuthApi implements CentralAuthApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoopApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeNotificationController extends NotificationController {
  @override
  Future<NotificationBootstrapState> build() async {
    return const NotificationBootstrapState(ready: true);
  }

  @override
  Future<void> unregisterPush() async {}
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository() : super();

  @override
  Future<void> logout() async {}
}

Future<void> _pumpAuthenticatedHome(
  WidgetTester tester, {
  required _FakeAuthController authController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => authController),
        secureStorageServiceProvider.overrideWithValue(SecureStorageService()),
        notificationControllerProvider.overrideWith(
          () => _FakeNotificationController(),
        ),
        settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
        policyFeaturesProvider.overrideWith(
          (ref) async => const PolicyFeatures(countryCode: 'BD'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuthGate(authenticatedChild: const FurtailHomeScreen()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'userName': 'Test User',
      'userEmail': 'test@example.com',
      'flutter.furtail_country_code': 'BD',
    });
  });

  testWidgets(
    'logout from the home drawer returns to login without emptying the navigator',
    (tester) async {
      final authController = _FakeAuthController();

      await _pumpAuthenticatedHome(tester, authController: authController);

      expect(find.byType(FurtailHomeScreen), findsOneWidget);

      final scaffoldFinder = find.byWidgetPredicate(
        (widget) => widget is Scaffold && widget.drawer != null,
      );
      final scaffoldState = tester.state<ScaffoldState>(scaffoldFinder);
      scaffoldState.openDrawer();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(Drawer), findsOneWidget);

      for (var i = 0; i < 4 && find.text('Logout').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Drawer), const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(find.text('Logout'), findsOneWidget);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(authController.logoutCalled, isTrue);
      expect(authController.state.status, AuthStatus.unauthenticated);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
