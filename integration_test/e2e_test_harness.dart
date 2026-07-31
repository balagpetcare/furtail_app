import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/main.dart' as app_main;
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/secure_storage_service.dart';
import 'package:furtail_app/core/config/central_auth_config.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/common/data/repositories/animal_taxonomy_repository.dart';
import 'package:furtail_app/features/common/data/repositories/bd_locations_repository.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/services/api_client.dart';

const String _defaultJwtSecret = 'change-me-very-secret-access-token-key-12345';
const bool _e2eTestMode = bool.fromEnvironment('E2E_TEST_MODE');

class E2eTestSession {
  E2eTestSession({
    required this.subject,
    required this.email,
    required this.displayName,
    String? issuer,
    String? audience,
    String? clientId,
    String? jwtSecret,
    String? refreshToken,
    Duration accessTokenTtl = const Duration(minutes: 30),
  }) : issuer = issuer ?? 'http://localhost:5010',
       audience = audience ?? CentralAuthConfig.clientId,
       clientId = clientId ?? CentralAuthConfig.clientId,
       jwtSecret = (jwtSecret == null || jwtSecret.isEmpty)
           ? _defaultJwtSecret
           : jwtSecret,
       refreshToken = refreshToken ?? _uniqueToken('refresh') {
    accessToken = _mintAccessToken(ttl: accessTokenTtl);
  }

  final String subject;
  final String email;
  final String displayName;
  final String issuer;
  final String audience;
  final String clientId;
  final String jwtSecret;
  String refreshToken;
  String? accessToken;
  int _accessTokenVersion = 1;
  int refreshCount = 0;

  void seed() {
    SecureStorageService.installTestState(
      accessToken: accessToken!,
      refreshToken: refreshToken,
    );
    CentralAuthApi.installRefreshTokenOverride(_refresh);
  }

  void clear() {
    SecureStorageService.clearTestState();
    CentralAuthApi.clearRefreshTokenOverride();
  }

  Future<CentralAuthTokenResult> _refresh(String providedRefreshToken) async {
    refreshCount += 1;
    if (providedRefreshToken != refreshToken) {
      throw CentralAuthException(
        message: 'Refresh token is no longer valid.',
        statusCode: 401,
        code: 'TOKEN_REVOKED',
      );
    }
    _accessTokenVersion += 1;
    refreshToken = _uniqueToken('refresh');
    accessToken = _mintAccessToken(ttl: const Duration(minutes: 30));
    await SecureStorageService().saveTokens(
      accessToken: accessToken!,
      refreshToken: refreshToken,
    );
    return CentralAuthTokenResult(
      accessToken: accessToken!,
      refreshToken: refreshToken,
      expiresIn: 1800,
    );
  }

  void expireAccessToken() {
    accessToken = _mintAccessToken(ttl: const Duration(seconds: -60));
    if (_e2eTestMode) {
      SecureStorageService.installTestState(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }
  }

  String _mintAccessToken({required Duration ttl}) {
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'sub': subject,
      'iss': issuer,
      'aud': audience,
      'client_id': clientId,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'nbf':
          now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch ~/
          1000,
      'exp': now.add(ttl).millisecondsSinceEpoch ~/ 1000,
      'email': email,
      'name': displayName,
      'roles': ['member'],
      'permissions': const <String>[],
      'scope': 'openid profile',
      'e2e_version': _accessTokenVersion,
    };
    return _signJwt(payload, jwtSecret);
  }

  static String _signJwt(Map<String, dynamic> payload, String secret) {
    const header = <String, dynamic>{'alg': 'HS256', 'typ': 'JWT'};
    final encodedHeader = _base64Url(jsonEncode(header));
    final encodedPayload = _base64Url(jsonEncode(payload));
    final signingInput = '$encodedHeader.$encodedPayload';
    final signature = Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(signingInput)).bytes;
    return '$signingInput.${_base64Url(signature)}';
  }

  static String _base64Url(Object input) {
    final bytes = input is String ? utf8.encode(input) : input as List<int>;
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _uniqueToken(String prefix) {
    final nonce = Random().nextInt(1 << 32).toRadixString(16);
    return '$prefix-$nonce-${DateTime.now().microsecondsSinceEpoch}';
  }
}

class E2eTestArtifacts {
  const E2eTestArtifacts({required this.imagePath, required this.videoPath});

  final String imagePath;
  final String videoPath;
}

class E2eRepositoryBundle {
  E2eRepositoryBundle()
    : apiClient = ApiClient(),
      posts = PostsRemoteDs(),
      adoption = AdoptionRepository(AdoptionRemoteDs(ApiClient())),
      fundraising = FundraisingRepository(ApiClient()),
      locations = BdLocationsRepository(ApiClient()),
      taxonomy = AnimalTaxonomyRepository(ApiClient());

  final ApiClient apiClient;
  final PostsRemoteDs posts;
  final AdoptionRepository adoption;
  final FundraisingRepository fundraising;
  final BdLocationsRepository locations;
  final AnimalTaxonomyRepository taxonomy;
}

class E2eCleanupBag {
  final List<Future<void> Function()> _tasks = [];

  void add(Future<void> Function() task) {
    _tasks.add(task);
  }

  Future<void> run() async {
    for (final task in _tasks.reversed) {
      try {
        await task();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }
}

class E2eTestHarness {
  E2eTestHarness._({required this.session, required this.artifacts});

  final E2eTestSession session;
  final E2eTestArtifacts artifacts;

  static Future<E2eTestHarness> install({
    String subject = 'e2e-mobile-user',
    String email = 'e2e.mobile@example.com',
    String displayName = 'E2E Mobile User',
    String? jwtSecret,
  }) async {
    final session = E2eTestSession(
      subject: subject,
      email: email,
      displayName: displayName,
      jwtSecret: jwtSecret,
    );
    session.seed();
    final artifacts = await _createArtifacts();
    return E2eTestHarness._(session: session, artifacts: artifacts);
  }

  Future<void> dispose() async {
    session.clear();
    await _deleteIfExists(artifacts.imagePath);
    await _deleteIfExists(artifacts.videoPath);
  }

  static Future<E2eTestArtifacts> _createArtifacts() async {
    final dir = await Directory.systemTemp.createTemp('furtail-e2e-');
    final imagePath = '${dir.path}${Platform.pathSeparator}fixture.png';
    final videoPath = '${dir.path}${Platform.pathSeparator}fixture.mp4';
    final imageBytes = await rootBundle.load(
      'assets/images/app_icon_furtail.png',
    );
    await File(imagePath).writeAsBytes(imageBytes.buffer.asUint8List());
    // The server only needs a stable binary with the right extension/content
    // type for upload-path coverage in tests. This is intentionally tiny.
    await File(videoPath).writeAsBytes(
      utf8.encode(
        'furtail-e2e-video-fixture:${DateTime.now().toIso8601String()}',
      ),
    );
    return E2eTestArtifacts(imagePath: imagePath, videoPath: videoPath);
  }
}

Future<void> waitForApiReady({
  Duration timeout = const Duration(seconds: 30),
  Uri? healthUri,
}) async {
  final uri = healthUri ?? Uri.parse('http://10.0.2.2:7300/health');
  final deadline = DateTime.now().add(timeout);
  Object? lastError;
  while (DateTime.now().isBefore(deadline)) {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return;
      }
      lastError = 'status=${response.statusCode} body=${response.body}';
    } catch (error) {
      lastError = error;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TestFailure('API readiness check failed for $uri: $lastError');
}

Future<void> pumpFurtailApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: app_main.FurtailApp()));
}

Future<void> launchAuthenticatedApp(
  WidgetTester tester,
  E2eTestSession session,
) async {
  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains(
          'ListTile background color or ink splashes may be invisible',
        ) ||
        message.contains('Please set a valid API key') ||
        message.contains('firebase_messaging/unknown') ||
        message.contains('response has a status code of 404') ||
        message.contains('FCM unavailable')) {
      return;
    }
    previousFlutterErrorHandler?.call(details);
  };
  try {
    session.seed();
    await pumpFurtailApp(tester);
    for (var i = 0; i < 8; i += 1) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(app_main.FurtailApp), findsOneWidget);
  } finally {
    FlutterError.onError = previousFlutterErrorHandler;
  }
}

Future<void> deleteTestArtifacts(E2eTestArtifacts artifacts) async {
  await _deleteIfExists(artifacts.imagePath);
  await _deleteIfExists(artifacts.videoPath);
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
  final parent = file.parent;
  if (await parent.exists()) {
    final entries = await parent.list().toList();
    if (entries.isEmpty) {
      await parent.delete();
    }
  }
}

Future<void> ensureAppInitialized() async {
  WidgetsFlutterBinding.ensureInitialized();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

Future<void> settleUntil(
  WidgetTester tester, {
  required Finder finder,
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 50),
  String description = 'expected widget',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $description.');
}

String uniqueDataSuffix([String prefix = 'e2e']) {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final nonce = Random().nextInt(1 << 32).toRadixString(16);
  return '$prefix-$stamp-$nonce';
}

void logSanitizedFailure(WidgetTester tester, String label) {
  debugPrint('[$label] widget tree snapshot start');
  debugDumpApp();
  debugPrint('[$label] widget tree snapshot end');
}
