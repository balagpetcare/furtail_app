import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppBar uses light (white) status-bar icons for readable contrast '
      'against the blue AppBar background', () {
    final appBarTheme = AppTheme.light.appBarTheme;
    expect(appBarTheme.systemOverlayStyle, SystemUiOverlayStyle.light);
  });
}
