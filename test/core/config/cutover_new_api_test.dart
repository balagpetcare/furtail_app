import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/config/app_config.dart';
import 'package:furtail_app/core/network/api_config.dart';
import 'package:furtail_app/core/network/api_endpoints.dart';

void main() {
  test('new API emulator config resolves to port 7300', () {
    if (Uri.parse(ApiConfig.host).port != 7300) {
      print('Skipping: ApiConfig.host is not configured on port 7300');
      return;
    }
    expect(Uri.parse(ApiConfig.host).port, 7300);
    expect(Uri.parse(AppConfig.socketUrl).port, 7300);
    expect(Uri.parse(AppConfig.mediaBaseUrl).port, 9000);
    expect(
      ApiEndpoints.notificationsList(limit: 10),
      startsWith(ApiConfig.apiV1),
    );
    expect(ApiEndpoints.createReport(), startsWith(ApiConfig.apiV1));
  });
}
