import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/auth/session_recovery.dart';

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      _store.containsKey(key);

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async => _store.clear();

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async =>
      _store[key];

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async =>
      Map.of(_store);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }
}

/// Fake CentralAuthApi whose [refreshToken] is instrumented to count calls
/// and optionally fail, delaying briefly so concurrent callers actually
/// overlap in the test.
class _CountingCentralAuthApi implements CentralAuthApi {
  int refreshCallCount = 0;
  final bool shouldFail;
  final bool returnEmptyRefreshToken;

  _CountingCentralAuthApi({this.shouldFail = false, this.returnEmptyRefreshToken = false});

  @override
  Future<CentralAuthTokenResult> refreshToken(String refreshToken) async {
    refreshCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (shouldFail) {
      throw CentralAuthException(message: 'Invalid or expired refresh token.', statusCode: 401);
    }
    return CentralAuthTokenResult(
      accessToken: 'new-access-$refreshCallCount',
      refreshToken: returnEmptyRefreshToken ? '' : 'new-refresh-$refreshCallCount',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();

  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService();
    await storage.clear();
  });

  test('refresh() succeeds: saves the rotated pair and returns the new access token', () async {
    await storage.saveTokens(accessToken: 'old-access', refreshToken: 'old-refresh');
    final api = _CountingCentralAuthApi();
    final recovery = SessionRecovery.test(secureStorage: storage, centralAuthApi: api);
    var sessionExpiredFired = false;
    recovery.onSessionExpired = () => sessionExpiredFired = true;

    final token = await recovery.refresh();

    expect(token, 'new-access-1');
    expect(await storage.accessToken, 'new-access-1');
    expect(await storage.refreshToken, 'new-refresh-1');
    expect(sessionExpiredFired, isFalse);
  });

  test('single-flight: N concurrent refresh() calls trigger exactly one network refresh', () async {
    await storage.saveTokens(accessToken: 'old-access', refreshToken: 'old-refresh');
    final api = _CountingCentralAuthApi();
    final recovery = SessionRecovery.test(secureStorage: storage, centralAuthApi: api);

    final results = await Future.wait([
      recovery.refresh(),
      recovery.refresh(),
      recovery.refresh(),
      recovery.refresh(),
      recovery.refresh(),
    ]);

    expect(api.refreshCallCount, 1);
    expect(results.every((t) => t == 'new-access-1'), isTrue);
  });

  test(
    'refresh failure (401 from Central Auth) clears the session and fires logout once',
    () async {
      await storage.saveTokens(accessToken: 'old-access', refreshToken: 'old-refresh');
      final api = _CountingCentralAuthApi(shouldFail: true);
      final recovery = SessionRecovery.test(secureStorage: storage, centralAuthApi: api);
      var sessionExpiredCount = 0;
      recovery.onSessionExpired = () => sessionExpiredCount++;

      final results = await Future.wait([
        recovery.refresh(),
        recovery.refresh(),
        recovery.refresh(),
      ]);

      expect(results.every((t) => t == null), isTrue);
      expect(sessionExpiredCount, 1, reason: 'logout must fire exactly once, not once per waiter');
      expect(await storage.accessToken, isNull);
      expect(await storage.refreshToken, isNull);
    },
  );

  test('missing rotated refresh token is treated as a definitive failure', () async {
    await storage.saveTokens(accessToken: 'old-access', refreshToken: 'old-refresh');
    final api = _CountingCentralAuthApi(returnEmptyRefreshToken: true);
    final recovery = SessionRecovery.test(secureStorage: storage, centralAuthApi: api);
    var sessionExpiredFired = false;
    recovery.onSessionExpired = () => sessionExpiredFired = true;

    final token = await recovery.refresh();

    expect(token, isNull);
    expect(sessionExpiredFired, isTrue);
    expect(await storage.accessToken, isNull);
  });

  test(
    'run() retries the action once with the refreshed token, never resending the expired one',
    () async {
      await storage.saveTokens(accessToken: 'expired-access', refreshToken: 'old-refresh');
      final api = _CountingCentralAuthApi();
      final recovery = SessionRecovery.test(secureStorage: storage, centralAuthApi: api);

      final seenTokens = <String>[];
      var callCount = 0;
      final result = await recovery.run<String>((token) async {
        seenTokens.add(token);
        callCount++;
        if (callCount == 1) {
          throw CentralAuthException(message: 'Invalid or expired access token.', statusCode: 401);
        }
        return 'ok:$token';
      }, isSessionExpired: (e) => e is CentralAuthException && e.isUnauthorized);

      expect(result, 'ok:new-access-1');
      expect(seenTokens, ['expired-access', 'new-access-1']);
      expect(callCount, 2, reason: 'exactly one retry, not repeated resends of the same token');
    },
  );

  test(
    'run() throws a friendly SessionRecoveryException on refresh failure, never the raw backend message',
    () async {
      await storage.saveTokens(accessToken: 'expired-access', refreshToken: 'old-refresh');
      final api = _CountingCentralAuthApi(shouldFail: true);
      final recovery = SessionRecovery.test(secureStorage: storage, centralAuthApi: api);

      Object? caught;
      try {
        await recovery.run<void>((token) async {
          throw CentralAuthException(message: 'Invalid or expired access token.', statusCode: 401);
        }, isSessionExpired: (e) => e is CentralAuthException && e.isUnauthorized);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<SessionRecoveryException>());
      final message = (caught as SessionRecoveryException).message;
      // The raw backend string must never surface to the UI layer.
      expect(message, isNot(contains('Invalid or expired access token')));
      expect(message, isNot(contains('old-refresh')));
      expect(message, isNot(contains('expired-access')));
    },
  );

  test('run() never includes a raw token value in any thrown message', () async {
    await storage.saveTokens(
      accessToken: 'super-secret-access-token-value',
      refreshToken: 'super-secret-refresh-token-value',
    );
    final api = _CountingCentralAuthApi(shouldFail: true);
    final recovery = SessionRecovery.test(secureStorage: storage, centralAuthApi: api);

    Object? caught;
    try {
      await recovery.run<void>((token) async {
        throw CentralAuthException(message: 'Invalid or expired access token.', statusCode: 401);
      }, isSessionExpired: (e) => e is CentralAuthException && e.isUnauthorized);
    } catch (e) {
      caught = e;
    }

    expect(caught.toString(), isNot(contains('super-secret')));
  });
}
