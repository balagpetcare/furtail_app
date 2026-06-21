# BPA App – Lightweight Build

## কী পরিবর্তন করা হয়েছে

### 1) Splash screen “অটকে থাকা” ফিক্স
- Splash এ SharedPreferences read করার সময় **timeout** যোগ করা হয়েছে
- কোনো error হলে Splash এ আটকে না থেকে **Login** এ চলে যাবে
- বড় `background.png` runtime এ আর লোড হয় না (memory/lag কমে)

### 2) APK size কমানো
- `video_trimmer` dependency **remove** করা হয়েছে (এটা FFmpeg native libs এনে APK অনেক বড় করে)
- `VideoTrimScreen` এখন **Lite preview** (trim না করে original video file return করে)

## Build commands

### Release (recommended flags)
```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
```

### Play Store (best)
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
```

## Assets (images) অপ্টিমাইজ করলে আরও size কমবে
1) `assets/images/` এর বড় PNG/JPG গুলো **WebP** করুন
2) বড় background image থাকলে (যেমন `background.png`) compression দিন অথবা resolution কমান

## যদি ভবিষ্যতে Trim দরকার হয়
Trim ফিচার চাইলে FFmpeg ভিত্তিক plugin লাগবে, ফলে size বাড়বে। তখন:
- per-ABI split + AAB ব্যবহার করুন
- অথবা server-side trimming করুন (API দিয়ে)
