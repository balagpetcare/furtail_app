import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/config/policy_features_provider.dart';
import 'package:furtail_app/features/home/presentation/screens/furtail_home_screen.dart';
import 'package:furtail_app/features/notifications/presentation/providers/notification_controller.dart';
import 'package:furtail_app/features/settings/data/repositories/settings_repository.dart';
import 'package:furtail_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/services/api_client.dart';
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

class _NoopSecureStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoopCentralAuthApi implements CentralAuthApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthController extends AuthController {
  _FakeAuthController()
    : super(_NoopSecureStorage(), _NoopCentralAuthApi(), _FakeApiClient()) {
    state = const AuthState(status: AuthStatus.authenticated);
  }

  @override
  Future<void> bootstrap() async {}
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

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(dio: Dio());

  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    return {
      'success': true,
      'data': {'items': const []},
    };
  }
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

  testWidgets('drawer My Pets opens the real pet list screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuthController()),
          secureStorageServiceProvider.overrideWithValue(
            SecureStorageService(),
          ),
          notificationControllerProvider.overrideWith(
            () => _FakeNotificationController(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          policyFeaturesProvider.overrideWith(
            (ref) async => const PolicyFeatures(countryCode: 'BD'),
          ),
          apiClientProvider.overrideWithValue(_FakeApiClient()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FurtailHomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final scaffoldFinder = find.byWidgetPredicate(
      (widget) => widget is Scaffold && widget.drawer != null,
    );
    final scaffoldState = tester.state<ScaffoldState>(scaffoldFinder);
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Pets').last);
    await tester.pumpAndSettle();

    expect(find.text('Pet list is coming soon. Stay tuned!'), findsNothing);
    expect(find.text('My Pets'), findsWidgets);
    expect(find.text('Register New Pet'), findsOneWidget);
  });
}
