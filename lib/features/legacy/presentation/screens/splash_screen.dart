import 'dart:async';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bpa_app/features/auth/presentation/screens/login_screen.dart';
import 'package:bpa_app/features/home/presentation/screens/bpa_home_screen.dart';
import 'package:bpa_app/core/storage/local_storage.dart';
import 'dart:ui' as ui;

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
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Keep splash short and never block indefinitely.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // ----------------------------------------
    // Language selection flow (UPDATED)
    // ----------------------------------------
    try {
      final savedLocale = await LocalStorage.getLocaleCode();
      if (savedLocale == null || (savedLocale != 'en' && savedLocale != 'bn')) {
        final deviceCode = ui.PlatformDispatcher.instance.locale.languageCode;
        final next = (deviceCode.toLowerCase().startsWith('bn')) ? 'bn' : 'en';
        await LocalStorage.setLocaleCode(next);
      }
    } catch (_) {}

    // Phase 5: First-launch country picker
    try {
      final country = await LocalStorage.getCountryCode();
      if (country == null || country.trim().isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/country-picker');
        return;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final token = prefs.getString('token');

      if (token != null && token.trim().isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BPAHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    return Scaffold(
      body: Stack(
        children: [
          // Lightweight background (avoid decoding a large full-screen bitmap).
          Positioned.fill(child: Container(color: _warmWhite)),

          // ✅ Text content
          SafeArea(
            child: Column(
              children: [
                // Move text a bit higher (previously it sat too low)
                const Spacer(flex: 3),

                // Small centered logo (cheap to decode).
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Image.asset(
                    'assets/images/splash_screen.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),
                ),

                // App name (bigger, deep green)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Bangladesh Pet Association",
                    textAlign: TextAlign.center,
                    style: context.appText.displayMedium!.copyWith(color: _deepGreen, fontWeight: FontWeight.w900, height: 1.2),
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline (blue)
                Text(
                  "We Care Your Love",
                  textAlign: TextAlign.center,
                  style: context.appText.bodyLarge!.copyWith(color: primary, fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 18),

                // Loader
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: primary,
                      backgroundColor: primary.withOpacity(0.15),
                    ),
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
