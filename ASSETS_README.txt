Furtail - Updated assets (logo + splash)

What changed:
- assets/images/logo.png (1024x1024) - for flutter_launcher_icons
- assets/images/splash_screen.png (1152x1152 centered) - for flutter_native_splash
- assets/images/background.png (2048x2048 light background) - for native splash background
- assets/images/doctor.png (1024x1024 transparent) - reusable illustration
- pubspec.yaml updated to include assets/images/ folder and splash/icon config.

After copying these files into your Flutter project root, run:

1) flutter pub get
2) dart run flutter_launcher_icons
3) dart run flutter_native_splash:create

Then rebuild the app.
