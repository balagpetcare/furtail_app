import 'package:flutter/material.dart';

/// Legacy theme controller — BPA locks [ThemeMode.light] only.
@Deprecated('Use themeModeProvider / MaterialApp themeMode instead.')
class ThemeController {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  void setThemeMode(ThemeMode mode) {
    themeMode.value = ThemeMode.light;
  }

  void toggle() {
    themeMode.value = ThemeMode.light;
  }
}
