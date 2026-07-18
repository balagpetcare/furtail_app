import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';

/// Captures every request body and replies with a canned success payload, so
/// we can assert that all session-issuing Central Auth calls carry the
/// `clientId` — without it, Central Auth signs tokens with its global
/// default audience ("bpa-mobile") which the Furtail API rejects, producing
/// the "Signed in, but your Furtail profile could not be loaded" failure.
class _CapturingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    bodies.add(data is Map<String, dynamic> ? data : <String, dynamic>{});
    return ResponseBody.fromString(
      jsonEncode({
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresIn': 900,
        'user': {'id': 'u1', 'email': 'a@b.com', 'roles': <String>[]},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _CapturingAdapter adapter;
  late CentralAuthApi api;

  setUp(() {
    adapter = _CapturingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://auth.test/api/v1'));
    dio.httpClientAdapter = adapter;
    api = CentralAuthApi.withDio(dio);
  });

  test('login sends clientId', () async {
    await api.login(identifier: 'a@b.com', password: 'pw');
    expect(adapter.bodies.single['clientId'], 'furtail-mobile');
  });

  test('register sends clientId', () async {
    await api.register(
      displayName: 'A',
      email: 'a@b.com',
      password: 'password1',
    );
    expect(adapter.bodies.single['clientId'], 'furtail-mobile');
  });

  test('requestOtp sends clientId', () async {
    await api.requestOtp(channel: 'email', recipient: 'a@b.com');
    expect(adapter.bodies.single['clientId'], 'furtail-mobile');
  });

  test('verifyOtp sends clientId', () async {
    await api.verifyOtp(channel: 'email', recipient: 'a@b.com', code: '123456');
    expect(adapter.bodies.single['clientId'], 'furtail-mobile');
  });

  test('loginPhone sends clientId', () async {
    await api.loginPhone(phone: '01700000000', password: 'pw');
    expect(adapter.bodies.single['clientId'], 'furtail-mobile');
  });

  test('identityLogin sends clientId', () async {
    await api.identityLogin(provider: 'google', idToken: 'tok');
    expect(adapter.bodies.single['clientId'], 'furtail-mobile');
  });

  test(
    'socialStartUrl carries app_client_id and registered redirect scheme',
    () {
      final url = CentralAuthApi.socialStartUrl('google');
      expect(url.path, endsWith('/auth/social/google/start'));
      expect(url.queryParameters['app_client_id'], 'furtail-mobile');
      expect(
        url.queryParameters['redirect_uri'],
        'furtailapp://oauth-callback',
      );
    },
  );
}
