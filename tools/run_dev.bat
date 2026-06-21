@echo off
setlocal
REM Dev run for both Emulator and Real device using LAN IP (no code changes).
flutter clean
flutter pub get
flutter run --dart-define-from-file=env\dev.json
