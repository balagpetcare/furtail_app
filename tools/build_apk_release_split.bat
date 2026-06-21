@echo off
setlocal
REM Release split APKs (arm64-v8a, armeabi-v7a, x86_64)
flutter clean
flutter pub get
flutter build apk --release --split-per-abi --dart-define-from-file=env\dev.json
echo.
echo Output:
echo build\app\outputs\flutter-apk\
