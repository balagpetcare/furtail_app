import 'package:flutter/material.dart';

import 'colors.dart';

/// Semantic Furtail design tokens — use instead of raw [Colors.*] in UI code.
abstract final class FurtailDesignTokens {
  static Color cardBackground(BuildContext context) =>
      Theme.of(context).cardTheme.color ?? AppPalette.lightBackground;

  static Color pageBackground(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color onPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color textMuted(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color border(BuildContext context) =>
      Theme.of(context).colorScheme.outline;

  static Color divider(BuildContext context) =>
      Theme.of(context).dividerColor;

  static const Color success = AppPalette.success;
  static const Color warning = AppPalette.warning;
  static const Color error = AppPalette.error;
  static const Color info = AppPalette.info;
  static const Color accentGold = AppPalette.secondary;
}
