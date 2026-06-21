/// WCAG-oriented accessibility constants (Material / Flutter).
abstract final class A11yConstants {
  /// Minimum recommended touch target (Material 3 / WCAG 2.5.5).
  static const double minTouchTarget = 48.0;

  /// WCAG AA normal text contrast ratio.
  static const double minContrastNormalText = 4.5;

  /// WCAG AA large text (≥18pt regular or ≥14pt bold).
  static const double minContrastLargeText = 3.0;
}
