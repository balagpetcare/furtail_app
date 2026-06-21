import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

/// Furtail always uses light theme — persisted value is ignored for UI mode.
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    await LocalStorage.setThemeMode('light');
    return ThemeMode.light;
  }

  /// No-op for dark/system — keeps API for settings compatibility.
  Future<void> setThemeMode(ThemeMode mode) async {
    await LocalStorage.setThemeMode('light');
    state = const AsyncData(ThemeMode.light);
  }
}
