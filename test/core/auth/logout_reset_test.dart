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

/// Avoids the real controller's push-notification/service bootstrapping
/// (unavailable in a widget-test environment) while still letting
/// [resetSessionScopedState] exercise its unregisterPush() call.
/// Only `logout()` is exercised by resetSessionScopedState(); every other
/// member forwards to noSuchMethod so this never accidentally hits the
/// network in a test environment.
class _FakeCentralAuthApi implements CentralAuthApi {
  @override
  Future<void> logout(String accessToken, {String? refreshToken}) async {}

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'userName': 'Jane Doe',
      'userEmail': 'jane@example.com',
    });
  });

  testWidgets(
    'resetSessionScopedState clears the canonical session exactly once and '
    'resets user-scoped local state without touching server data',
    (tester) async {
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

      final secureStorage = container.read(secureStorageServiceProvider);
      await secureStorage.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );
      await container.read(currentUserProvider.notifier).reloadFromPrefs();

      expect(await secureStorage.accessToken, 'access-token');
      expect(container.read(currentUserProvider).name, 'Jane Doe');

      await resetSessionScopedState(capturedRef);

      expect(await secureStorage.accessToken, isNull);
      expect(await secureStorage.refreshToken, isNull);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(container.read(currentUserProvider).name, 'Guest');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('userName'), isNull);
      expect(prefs.getString('userEmail'), isNull);

      final fake =
          container.read(notificationControllerProvider.notifier)
              as _FakeNotificationController;
      expect(fake.unregisterCalls, 1);
    },
  );
}
