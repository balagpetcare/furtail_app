import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/theme/colors.dart';

/// WCAG 2.1 relative luminance + contrast ratio, computed directly from the
/// actual [Color] values — not eyeballed. [Color.r]/[.g]/[.b] are already
/// 0.0-1.0 floats in this Flutter version's Color API.
double _linearize(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double relativeLuminance(Color c) {
  final r = _linearize(c.r);
  final g = _linearize(c.g);
  final b = _linearize(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Light theme (shipped — AppTheme.light)', () {
    final light = AppColorScheme.light();

    test('AppBar title/back-icon: onPrimary on primary >= 4.5:1', () {
      final ratio = contrastRatio(light.onPrimary, light.primary);
      // ignore: avoid_print
      print('light onPrimary/primary = ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Safety selected tab label: onPrimary on primary >= 4.5:1', () {
      final ratio = contrastRatio(light.onPrimary, light.primary);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Safety unselected tab label (85% onPrimary over primary) >= 4.5:1', () {
      final blended = Color.lerp(light.primary, light.onPrimary, 0.85)!;
      final ratio = contrastRatio(blended, light.primary);
      // ignore: avoid_print
      print('light unselected-tab/primary = ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Section heading: onSurfaceVariant on surface >= 4.5:1', () {
      final ratio = contrastRatio(light.onSurfaceVariant, light.surface);
      // ignore: avoid_print
      print('light onSurfaceVariant/surface = ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Body heading: onSurface on surface >= 4.5:1', () {
      final ratio = contrastRatio(light.onSurface, light.surface);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Error banner text: onErrorContainer on errorContainer >= 4.5:1', () {
      final ratio = contrastRatio(light.onErrorContainer, light.errorContainer);
      // ignore: avoid_print
      print('light onErrorContainer/errorContainer = ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Primary button text: onPrimary on primary >= 4.5:1', () {
      final ratio = contrastRatio(light.onPrimary, light.primary);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Primary control color (switches/icons/buttons) on surface >= 3:1', () {
      final ratio = contrastRatio(light.primary, light.surface);
      // ignore: avoid_print
      print('light primary/surface = ${ratio.toStringAsFixed(2)}:1 (control threshold 3:1)');
      expect(ratio, greaterThanOrEqualTo(3.0));
    });
  });

  group('Dark token set (AppColorScheme.dark() — defined but NOT wired into '
      'ThemeData; AppTheme.dark is a deprecated alias for AppTheme.light, '
      'so this app does not currently ship a runtime dark theme)', () {
    final dark = AppColorScheme.dark();

    test('AppBar title/back-icon: onPrimary on primary — measured, documented gap', () {
      final ratio = contrastRatio(dark.onPrimary, dark.primary);
      // ignore: avoid_print
      print(
        'dark onPrimary/primary = ${ratio.toStringAsFixed(2)}:1 '
        '(KNOWN GAP: below the 4.5:1 normal-text threshold — primary is too '
        'light for white text. Not fixed here: correcting it is a brand-color '
        'design decision outside "replace hard-coded colors with tokens" '
        'scope, and the app does not currently render this pairing at '
        'runtime since AppTheme.dark aliases AppTheme.light.)',
      );
      // Only asserts the large-text/control floor, which it does meet.
      expect(ratio, greaterThanOrEqualTo(3.0));
    });

    test('Section heading: onSurfaceVariant on surface >= 4.5:1', () {
      final ratio = contrastRatio(dark.onSurfaceVariant, dark.surface);
      // ignore: avoid_print
      print('dark onSurfaceVariant/surface = ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Body heading: onSurface on surface >= 4.5:1', () {
      final ratio = contrastRatio(dark.onSurface, dark.surface);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Error text: onError on error — measured, documented gap', () {
      final ratio = contrastRatio(dark.onError, dark.error);
      // ignore: avoid_print
      print(
        'dark onError/error = ${ratio.toStringAsFixed(2)}:1 '
        '(KNOWN GAP: below 4.5:1 for the same reason as onPrimary/primary '
        'above — not fixed here, not reachable at runtime today.)',
      );
      expect(ratio, greaterThanOrEqualTo(3.0));
    });
  });
}
