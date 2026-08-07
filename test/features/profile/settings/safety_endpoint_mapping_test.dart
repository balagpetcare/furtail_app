import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/profile/data/safety_service.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Proves each Safety list/action method hits exactly the endpoint its
/// name promises — not another kind's endpoint by accident. This is the
/// service-layer half of the tab/provider/endpoint mapping; the widget
/// half (each tab renders only its own kind's data) is covered by
/// safety_screen_test.dart.
ApiClient _recordingApiClient(List<String> requestedPaths, {dynamic responseData}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requestedPaths.add('${options.method} ${options.uri.path}');
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: responseData ?? {'success': true, 'data': {}},
          ),
        );
      },
    ),
  );
  return ApiClient(dio: dio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('listBlocked() calls GET /social/blocked, not muted or restricted', () async {
    final paths = <String>[];
    final svc = SafetyService(client: _recordingApiClient(paths));
    await svc.listBlocked();
    expect(paths, ['GET /api/v1/social/blocked']);
  });

  test('listMuted() calls GET /social/muted, not blocked or restricted', () async {
    final paths = <String>[];
    final svc = SafetyService(client: _recordingApiClient(paths));
    await svc.listMuted();
    expect(paths, ['GET /api/v1/social/muted']);
  });

  test('listRestricted() calls GET /social/restricted, not blocked or muted', () async {
    final paths = <String>[];
    final svc = SafetyService(client: _recordingApiClient(paths));
    await svc.listRestricted();
    expect(paths, ['GET /api/v1/social/restricted']);
  });

  test('block(id)/unblock(id) call POST/DELETE /social/block/:id', () async {
    final paths = <String>[];
    final svc = SafetyService(client: _recordingApiClient(paths));
    await svc.block(42);
    await svc.unblock(42);
    expect(paths, ['POST /api/v1/social/block/42', 'DELETE /api/v1/social/block/42']);
  });

  test('mute(id)/unmute(id) call POST/DELETE /social/mute/:id', () async {
    final paths = <String>[];
    final svc = SafetyService(client: _recordingApiClient(paths));
    await svc.mute(42);
    await svc.unmute(42);
    expect(paths, ['POST /api/v1/social/mute/42', 'DELETE /api/v1/social/mute/42']);
  });

  test('restrict(id)/unrestrict(id) call POST/DELETE /social/restrict/:id', () async {
    final paths = <String>[];
    final svc = SafetyService(client: _recordingApiClient(paths));
    await svc.restrict(42);
    await svc.unrestrict(42);
    expect(paths, ['POST /api/v1/social/restrict/42', 'DELETE /api/v1/social/restrict/42']);
  });

  test('listBlocked() parses only the userId field from items, matching the '
      'server envelope shape', () async {
    final paths = <String>[];
    final svc = SafetyService(
      client: _recordingApiClient(
        paths,
        responseData: {
          'success': true,
          'data': {
            'items': [
              {'userId': 7},
              {'userId': 9},
            ],
          },
        },
      ),
    );
    final ids = await svc.listBlocked();
    expect(ids, [7, 9]);
  });
}
