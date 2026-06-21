import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

/// Riverpod-only locale controller (Furtail rule).
/// - Loads saved locale from SharedPreferences.
/// - Defaults to English if nothing selected.
final localeControllerProvider = AsyncNotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async {
    final code = await LocalStorage.getLocaleCode();
    if (code == 'bn') return const Locale('bn');
    if (code == 'en') return const Locale('en');

    // ✅ First app open: auto-pick default language based on device locale
    // (Requirement: do not show language picker on startup)
    final deviceCode = PlatformDispatcher.instance.locale.languageCode;
    final next = (deviceCode.toLowerCase().startsWith('bn')) ? 'bn' : 'en';
    await LocalStorage.setLocaleCode(next);
    return Locale(next);
  }

  Future<void> setLocale(String code) async {
    final next = (code == 'bn') ? const Locale('bn') : const Locale('en');
    await LocalStorage.setLocaleCode(next.languageCode);
    state = AsyncData(next);
  }

  Future<bool> hasUserChosenLanguage() async {
    final code = await LocalStorage.getLocaleCode();
    return code != null && (code == 'en' || code == 'bn');
  }
}
