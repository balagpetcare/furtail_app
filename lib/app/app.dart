import 'package:furtail_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../features/legacy/presentation/screens/splash_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme,
      // ❌ Do NOT wrap the entire Navigator in SafeArea here.
      //    Flutter's Scaffold + AppBar already handle safe areas (status bar,
      //    notch, nav bar) correctly per-screen. A global SafeArea here would
      //    consume the top inset before any AppBar can paint its background
      //    under the status bar, causing the status-bar region to appear
      //    transparent / wrong color.
      home: SplashScreen(),
    );
  }
}
