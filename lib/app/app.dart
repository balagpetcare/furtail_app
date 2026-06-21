import 'package:bpa_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../features/legacy/presentation/screens/splash_screen.dart';

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme, // ✅
      builder: (context, child) {
        // Global SafeArea to prevent content from going under notch/camera areas
        return SafeArea(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: SplashScreen(),
    );
  }
}
