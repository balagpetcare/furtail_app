// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/logout_reset.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/providers/current_user_provider.dart';
import 'package:furtail_app/features/notifications/presentation/providers/notification_controller.dart';
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

class _FakeCentralAuthApi implements CentralAuthApi {
  bool logoutCalled = false;
  bool logoutThrows = false;

  @override
  Future<void> logout(String accessToken, {String? refreshToken}) async {
    logoutCalled = true;
    if (logoutThrows) {
      throw Exception('Remote logout failed');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationController extends NotificationController {
  int unregisterCalls = 0;

  @override
  Future<NotificationBootstrapState> build() async {
    return const NotificationBootstrapState(ready: true);
  }

  @override
  Future<void> unregisterPush() async {
    unregisterCalls += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();

  group('Logout Flow', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'userName': 'Test User',
        'userEmail': 'test@example.com',
      });
    });

    testWidgets(
      'Successful logout clears all auth state and updates AuthController status',
      (tester) async {
        late WidgetRef capturedRef;
        final fakeApi = _FakeCentralAuthApi();
        final container = ProviderContainer(
          overrides: [
            notificationControllerProvider.overrideWith(
              () => _FakeNotificationController(),
            ),
            centralAuthApiProvider.overrideWithValue(fakeApi),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Setup: create an authenticated session
        final secureStorage = container.read(secureStorageServiceProvider);
        await secureStorage.saveTokens(
          accessToken: 'access-token-123',
          refreshToken: 'refresh-token-456',
        );

        expect(await secureStorage.accessToken, 'access-token-123');
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.unknown, // Not bootstrapped yet
        );

        // Act: perform logout
        await resetSessionScopedState(capturedRef);

        // Assert: tokens are cleared
        expect(await secureStorage.accessToken, isNull);
        expect(await secureStorage.refreshToken, isNull);

        // Assert: auth status is unauthenticated
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.unauthenticated,
        );

        // Assert: remote logout was attempted
        expect(fakeApi.logoutCalled, isTrue);
      },
    );

    testWidgets(
      'Remote logout failure does not prevent local session cleanup',
      (tester) async {
        late WidgetRef capturedRef;
        final fakeApi = _FakeCentralAuthApi()..logoutThrows = true;
        final container = ProviderContainer(
          overrides: [
            notificationControllerProvider.overrideWith(
              () => _FakeNotificationController(),
            ),
            centralAuthApiProvider.overrideWithValue(fakeApi),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        await tester.pump();

        final secureStorage = container.read(secureStorageServiceProvider);
        await secureStorage.saveTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );

        // Act: logout even though remote logout will fail
        await resetSessionScopedState(capturedRef);

        // Assert: local state is still cleared despite remote failure
        expect(await secureStorage.accessToken, isNull);
        expect(await secureStorage.refreshToken, isNull);
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.unauthenticated,
        );
      },
    );

    testWidgets('Logout clears cached user data and shared preferences', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      final container = ProviderContainer(
        overrides: [
          notificationControllerProvider.overrideWith(
            () => _FakeNotificationController(),
          ),
          centralAuthApiProvider.overrideWithValue(_FakeCentralAuthApi()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await container.read(currentUserProvider.notifier).reloadFromPrefs();
      expect(container.read(currentUserProvider).name, 'Test User');

      // Act: logout
      await resetSessionScopedState(capturedRef);

      // Assert: user data is cleared
      expect(container.read(currentUserProvider).name, 'Guest');

      // Assert: shared preferences are cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('userName'), isNull);
      expect(prefs.getString('userEmail'), isNull);
    });

    testWidgets('Logout unregisters push notifications', (tester) async {
      late WidgetRef capturedRef;
      final container = ProviderContainer(
        overrides: [
          notificationControllerProvider.overrideWith(
            () => _FakeNotificationController(),
          ),
          centralAuthApiProvider.overrideWithValue(_FakeCentralAuthApi()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Act: logout
      await resetSessionScopedState(capturedRef);

      // Assert: push was unregistered once
      final notifController =
          container.read(notificationControllerProvider.notifier)
              as _FakeNotificationController;
      expect(notifController.unregisterCalls, 1);
    });

    testWidgets('Multiple logout calls do not cause issues', (tester) async {
      late WidgetRef capturedRef;
      final fakeApi = _FakeCentralAuthApi();
      final container = ProviderContainer(
        overrides: [
          notificationControllerProvider.overrideWith(
            () => _FakeNotificationController(),
          ),
          centralAuthApiProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final secureStorage = container.read(secureStorageServiceProvider);
      await secureStorage.saveTokens(
        accessToken: 'token',
        refreshToken: 'refresh',
      );

      // Act: call logout twice
      await resetSessionScopedState(capturedRef);
      await resetSessionScopedState(capturedRef);

      // Assert: auth is still unauthenticated (idempotent)
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(await secureStorage.accessToken, isNull);
    });
  });
}
