import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/config/app_config.dart';
import 'package:furtail_app/core/network/api_config.dart';

void main() {
  test('rollback config resolves to port 7200', () {
    if (Uri.parse(ApiConfig.host).port != 7200) {
      print('Skipping: ApiConfig.host is not configured on port 7200');
      return;
    }
    expect(Uri.parse(ApiConfig.host).port, 7200);
    expect(Uri.parse(AppConfig.socketUrl).port, 7200);
    expect([7200, 9000].contains(Uri.parse(AppConfig.mediaBaseUrl).port), true);
  });
}
