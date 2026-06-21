# BPA Flutter App – Professional Setup (Play Store Ready)

> এই ZIP এ শুধুমাত্র `lib/`, `assets/` এবং `pubspec.yaml` আছে (আপনার মূল Flutter project এর ভিতরে এগুলো replace/copy করতে হবে)।

## 1) Splash Screen & Logo
- **Splash (app open এর পরপর):** `assets/images/splash_screen.png`
- **Logo (Login + Home header):** `assets/images/doctor.png`
- **App icon (launcher):** `assets/images/logo.png`

### Splash (native)
`pubspec.yaml` এ `flutter_native_splash` কনফিগ দেয়া আছে। রান করুন:
```bash
flutter pub get
flutter pub run flutter_native_splash:create
```

### Launcher Icon
`flutter_launcher_icons` কনফিগ দেয়া আছে। রান করুন:
```bash
flutter pub run flutter_launcher_icons
```

## 2) Social Login (Google + Facebook Ready)
এই ভার্সনে **Google** এবং **Facebook** লগইন full wired করা আছে (frontend + backend endpoint)।
Instagram/TikTok/WhatsApp বাটনগুলো **Coming soon** হিসেবে আছে।

### Flutter (Google)
1. Google Cloud Console থেকে OAuth Client তৈরি করুন (Android/iOS অনুযায়ী)।
2. Android এর জন্য SHA1/SHA256 সেট করুন।
3. `android/app/google-services.json` (Firebase ব্যবহার করলে) অথবা `google_sign_in` এর ক্লায়েন্ট কনফিগ করুন।

### Flutter (Facebook)
1. Meta Developers এ Facebook App তৈরি করুন।
2. Android package name + Key Hash সেট করুন।

> **Note:** এই ZIP এ `android/` ও `ios/` folder নেই, তাই আপনার মূল Flutter project এর android/ios এ প্রয়োজনীয় সেটিং করতে হবে।

## 3) Backend Endpoint
Frontend এই endpoint call করে:
- `POST /api/v1/auth/social/google`  body: `{ "idToken": "..." }`
- `POST /api/v1/auth/social/facebook` body: `{ "accessToken": "..." }`

আপনার API base URL `lib/core/network/api_config.dart` এ আছে।

## 4) Release build (Play Store)
আপনার মূল Flutter project এ নিচের কাজগুলো করুন:
- `applicationId` (Android package name) ফাইনাল করুন
- `version: x.y.z+build` আপডেট করুন
- `android/app` এ keystore generate + `key.properties` সেট করুন
- Privacy Policy URL, Data safety form, Screenshots, Feature Graphic প্রস্তুত করুন

### Common Commands
```bash
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release
```


## API Host (আপনার PC IP)

এই প্রজেক্টে API URL `dart-define` দিয়ে ওভাররাইড করা যায়:

- **LAN (real device / same WiFi):**
  ```bash
  flutter run --dart-define=API_HOST=http://192.168.10.111:3000
  ```

- **Android Emulator:**
  ```bash
  flutter run --dart-define=API_HOST=http://10.0.2.2:3000
  ```

ডিফল্ট হিসেবে `http://192.168.10.111:3000` সেট করা আছে (ApiConfig).
