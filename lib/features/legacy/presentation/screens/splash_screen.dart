import 'dart:async';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:furtail_app/features/auth/presentation/screens/login_screen.dart';
import 'package:furtail_app/features/home/presentation/screens/furtail_home_screen.dart';
import 'package:furtail_app/core/storage/local_storage.dart';
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
          MaterialPageRoute(builder: (_) => const FurtailHomeScreen()),
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
    // Use Scaffold backgroundColor instead of Stack+Positioned.fill so the
    // Column gets the full tight width constraint from the Scaffold body,
    // preventing content from drifting left on all screen sizes.
    return Scaffold(
      backgroundColor: _warmWhite,
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              Image.asset(
                'assets/images/splash_screen.png',
                height: 110,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),

              Text(
                "Furtail",
                textAlign: TextAlign.center,
                style: context.appText.displayMedium!.copyWith(
                  color: _deepGreen, fontWeight: FontWeight.w900, height: 1.2),
              ),
              const SizedBox(height: 8),

              Text(
                "We Care Your Love",
                textAlign: TextAlign.center,
                style: context.appText.bodyLarge!.copyWith(
                  color: primary, fontWeight: FontWeight.w700),
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

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
