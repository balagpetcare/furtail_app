import 'package:flutter/material.dart';

import 'bpa_design_tokens.dart';

/// Theme-aware shortcuts (prefer over hardcoded colors).
extension AppThemeContext on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  ThemeData get appTheme => Theme.of(this);

  /// BPA locks light theme — always false regardless of device setting.
  bool get isDarkMode => false;

  Color get primaryColor => colorScheme.primary;

  Color get surfaceColor => colorScheme.surface;

  Color get onSurfaceColor => colorScheme.onSurface;

  Color get outlineColor => colorScheme.outline;

  Color get scaffoldBg => appTheme.scaffoldBackgroundColor;

  /// Card / sheet surface (theme-aware).
  Color get cardSurface => colorScheme.brightness == Brightness.light
      ? colorScheme.surface
      : colorScheme.surfaceContainerHighest;

  /// Secondary/muted text color (theme-aware).
  Color get mutedTextColor => colorScheme.onSurfaceVariant;

  /// Elevated card surface (white in BPA light theme).
  Color get bpaCardColor =>
      appTheme.cardTheme.color ?? colorScheme.surface;

  Color get bpaSuccess => BpaDesignTokens.success;

  Color get bpaError => BpaDesignTokens.error;
}
