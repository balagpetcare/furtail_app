import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Central Furtail typography scale (Facebook-style readability).
abstract final class AppTypographyScale {
  static const double displayLarge = 28;
  static const double displayMedium = 24;
  static const double pageTitle = 22;
  static const double sectionTitle = 18;
  static const double menuTitle = 16;
  static const double cardTitle = 16;
  static const double bodyLarge = 15;
  static const double bodyRegular = 14;
  static const double caption = 12;
  static const double meta = 11;

  /// Drawer / sidebar (no oversized menu fonts).
  static const double drawerSection = 13;
  static const double drawerMenu = 16;
  static const double drawerSubtitle = 12;
}

/// Builds Material [TextTheme] and semantic styles for the whole app.
abstract final class AppTypography {
  static const List<String> fontFamilyFallback = [
    'Roboto',
    'Kohinoor Bangla',
    'Noto Sans Bengali',
    'system-ui',
  ];

  static TextStyle _inter({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: fontFamilyFallback);
  }

  static TextTheme buildTextTheme({
    Color primary = AppColors.textPrimary,
    Color secondary = AppColors.textSecondary,
    Color tertiary = AppColors.textTertiary,
  }) {
    TextStyle s({
      required double size,
      FontWeight weight = FontWeight.w400,
      Color? c,
    }) =>
        _inter(fontSize: size, fontWeight: weight, color: c ?? primary);

    return TextTheme(
      displayLarge: s(size: AppTypographyScale.displayLarge, weight: FontWeight.w700),
      displayMedium: s(size: AppTypographyScale.displayMedium, weight: FontWeight.w700),
      displaySmall: s(size: AppTypographyScale.pageTitle, weight: FontWeight.w600),
      headlineLarge: s(size: AppTypographyScale.displayMedium, weight: FontWeight.w700),
      headlineMedium: s(size: AppTypographyScale.pageTitle, weight: FontWeight.w600),
      headlineSmall: s(size: AppTypographyScale.sectionTitle, weight: FontWeight.w600),
      titleLarge: s(size: AppTypographyScale.pageTitle, weight: FontWeight.w600),
      titleMedium: s(size: AppTypographyScale.sectionTitle, weight: FontWeight.w600),
      titleSmall: s(size: AppTypographyScale.menuTitle, weight: FontWeight.w500),
      bodyLarge: s(
        size: AppTypographyScale.bodyLarge,
        weight: FontWeight.w400,
        c: secondary,
      ),
      bodyMedium: s(
        size: AppTypographyScale.bodyRegular,
        weight: FontWeight.w400,
        c: secondary,
      ),
      bodySmall: s(
        size: AppTypographyScale.caption,
        weight: FontWeight.w400,
        c: tertiary,
      ),
      labelLarge: s(size: AppTypographyScale.menuTitle, weight: FontWeight.w600),
      labelMedium: s(
        size: AppTypographyScale.caption,
        weight: FontWeight.w600,
        c: tertiary,
      ),
      labelSmall: s(
        size: AppTypographyScale.meta,
        weight: FontWeight.w500,
        c: tertiary,
      ),
    );
  }

  static TextStyle displayLarge(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.displayLarge!, color: color);

  static TextStyle displayMedium(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.displayMedium!, color: color);

  static TextStyle pageTitle(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.titleLarge!, color: color);

  static TextStyle sectionTitle(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.titleMedium!, color: color);

  static TextStyle menuTitle(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.labelLarge!, color: color);

  static TextStyle cardTitle(BuildContext context, {Color? color}) =>
      menuTitle(context, color: color);

  static TextStyle bodyLarge(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.bodyLarge!, color: color);

  static TextStyle bodyRegular(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.bodyMedium!, color: color);

  static TextStyle caption(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.bodySmall!, color: color);

  static TextStyle meta(BuildContext context, {Color? color}) =>
      _fromTheme(context, (t) => t.labelSmall!, color: color);

  static TextStyle drawerSection(BuildContext context, {Color? color}) =>
      _inter(
        fontSize: AppTypographyScale.drawerSection,
        fontWeight: FontWeight.w700,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
      );

  static TextStyle drawerMenu(BuildContext context, {Color? color}) =>
      _inter(
        fontSize: AppTypographyScale.drawerMenu,
        fontWeight: FontWeight.w600,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle drawerSubtitle(BuildContext context, {Color? color}) =>
      _inter(
        fontSize: AppTypographyScale.drawerSubtitle,
        fontWeight: FontWeight.w400,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      );

  static TextStyle styleForLegacySize(
    BuildContext context,
    int fontSize, {
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    final theme = Theme.of(context).textTheme;
    final TextStyle base;
    switch (fontSize) {
      case >= 28:
        base = theme.displayLarge!;
      case >= 24:
        base = theme.displayMedium!;
      case >= 22:
        base = theme.titleLarge!;
      case >= 18:
        base = theme.titleMedium!;
      case >= 16:
        base = theme.labelLarge!;
      case >= 15:
        base = theme.bodyLarge!;
      case >= 14:
        base = theme.bodyMedium!;
      case >= 12:
        base = theme.bodySmall!;
      default:
        base = theme.labelSmall!;
    }
    return base.copyWith(
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle _fromTheme(
    BuildContext context,
    TextStyle Function(TextTheme t) pick, {
    Color? color,
  }) {
    final style = pick(Theme.of(context).textTheme);
    return color == null ? style : style.copyWith(color: color);
  }
}

/// Convenient themed text access (legacy + new APIs).
extension AppTypographyContext on BuildContext {
  TextTheme get appText => Theme.of(this).textTheme;
}
