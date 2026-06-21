import 'package:flutter/material.dart';

/// Semantic color tokens for light and dark Material 3 [ColorScheme]s.
abstract final class AppPalette {
  static const Color primary = Color(0xFF1E60AA);
  static const Color secondary = Color(0xFFFFD700);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFB91C1C);
  static const Color info = Color(0xFF2D7FF9);

  // Light surfaces
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightSurfaceContainer = Color(0xFFF6F8FB);
  static const Color lightOutline = Color(0xFFE6E6E6);
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  static const Color lightOnSurfaceVariant = Color(0xFF666666);
  /// Muted text — ≥4.5:1 on white (WCAG AA body text).
  static const Color lightOutlineVariant = Color(0xFF5C5C5C);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1A1F26);
  static const Color darkSurfaceContainer = Color(0xFF232A33);
  static const Color darkOutline = Color(0xFF3A4452);
  static const Color darkOnSurface = Color(0xFFF3F4F6);
  static const Color darkOnSurfaceVariant = Color(0xFFB8BFC8);
  static const Color darkOutlineVariant = Color(0xFF8A939E);
}

abstract final class AppColorScheme {
  static ColorScheme light() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      secondary: AppPalette.secondary,
      onSecondary: AppPalette.lightOnSurface,
      tertiary: AppPalette.info,
      onTertiary: Colors.white,
      error: AppPalette.error,
      onError: Colors.white,
      surface: AppPalette.lightSurface,
      onSurface: AppPalette.lightOnSurface,
      onSurfaceVariant: AppPalette.lightOnSurfaceVariant,
      outline: AppPalette.lightOutline,
      outlineVariant: AppPalette.lightOutlineVariant,
      shadow: Colors.black26,
      surfaceContainerHighest: AppPalette.lightSurfaceContainer,
    );
  }

  static ColorScheme dark() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF5B8FD4),
      onPrimary: Colors.white,
      secondary: AppPalette.secondary,
      onSecondary: AppPalette.darkOnSurface,
      tertiary: Color(0xFF6BA3F5),
      onTertiary: Colors.white,
      error: Color(0xFFEF6B6B),
      onError: Colors.white,
      surface: AppPalette.darkSurface,
      onSurface: AppPalette.darkOnSurface,
      onSurfaceVariant: AppPalette.darkOnSurfaceVariant,
      outline: AppPalette.darkOutline,
      outlineVariant: AppPalette.darkOutlineVariant,
      shadow: Colors.black54,
      surfaceContainerHighest: AppPalette.darkSurfaceContainer,
    );
  }
}
