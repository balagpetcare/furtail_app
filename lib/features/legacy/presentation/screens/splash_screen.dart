import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';

import 'package:furtail_app/core/storage/local_storage.dart';
import 'dart:ui' as ui;

/// Pure presentational splash screen. Navigation is now owned by
/// [AuthGate] (see lib/core/auth/auth_gate.dart) based on
/// [AuthController]'s bootstrap result — this widget no longer makes any
/// navigation decisions itself.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _deepGreen = Color(0xFF0B5D3B);
  static const Color _warmWhite = Color(0xFFFAF4E8);

  @override
  void initState() {
    super.initState();
    _applyDefaults();
  }

  Future<void> _applyDefaults() async {
    // ----------------------------------------
    // Language selection flow (unrelated to auth — preserved)
    // ----------------------------------------
    try {
      final savedLocale = await LocalStorage.getLocaleCode();
      if (savedLocale == null || (savedLocale != 'en' && savedLocale != 'bn')) {
        final deviceCode = ui.PlatformDispatcher.instance.locale.languageCode;
        final next = (deviceCode.toLowerCase().startsWith('bn')) ? 'bn' : 'en';
        await LocalStorage.setLocaleCode(next);
      }
    } catch (_) {}

    // Country is optional at startup. Keep BD as the internal fallback.
    try {
      final country = await LocalStorage.getCountryCode();
      if (country == null || country.trim().isEmpty) {
        await LocalStorage.setCountryCode('BD');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    return Scaffold(
      backgroundColor: _warmWhite,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash_doctor_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SizedBox.expand(
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  Text(
                    "Furtail",
                    textAlign: TextAlign.center,
                    style: context.appText.displayMedium!.copyWith(
                      color: _deepGreen,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We Care Your Love",
                    textAlign: TextAlign.center,
                    style: context.appText.bodyLarge!.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: primary,
                      backgroundColor: primary.withValues(alpha: 0.15),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
