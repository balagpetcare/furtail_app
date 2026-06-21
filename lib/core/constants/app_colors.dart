import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// @deprecated Prefer [Theme.of(context).colorScheme] or [AppPalette].
class AppColors {
  static const Color primary = AppPalette.primary;
  static const Color donateBlue = AppPalette.primary;
  static const Color accentGold = AppPalette.secondary;
  static const Color successGreen = AppPalette.success;

  static const Color textPrimary = AppPalette.lightOnSurface;
  static const Color textSecondary = AppPalette.lightOnSurfaceVariant;
  static const Color textTertiary = AppPalette.lightOutlineVariant;

  static const Color background = AppPalette.lightBackground;
  static const Color surface = AppPalette.lightSurface;
}
