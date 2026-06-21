import 'package:flutter/material.dart';

import '../theme/typography.dart';
import 'app_colors.dart';

/// @deprecated Prefer [Theme.of(context).textTheme] or [AppTypography.buildTextTheme].
class AppTextStyles {
  static TextTheme get _theme => AppTypography.buildTextTheme();

  static TextStyle get headline1 => _theme.displayLarge!;

  static TextStyle get headline2 => _theme.headlineLarge!;

  static TextStyle get bodyLarge => _theme.bodyLarge!;

  static TextStyle get bodyMedium => _theme.bodyMedium!;

  static TextStyle get caption => _theme.bodySmall!;

  static TextStyle get rewardPoints => _theme.titleLarge!.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.accentGold,
      );

  static TextStyle get taskCompleted => _theme.labelLarge!.copyWith(
        color: AppColors.successGreen,
      );
}
