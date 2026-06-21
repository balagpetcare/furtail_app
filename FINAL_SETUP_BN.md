# Furtail v8.1.x Final (Emulator + Real Phone)

## আপনার LAN IP
- PC IP: **192.168.10.111**
- API: `http://192.168.10.111:3000`
- MinIO: `http://192.168.10.111:9000`

## ১) Dev রান (Emulator বা Real ফোন — একই কমান্ড)
```bash
flutter clean
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

## ২) Release APK build (split-per-abi)
```bash
flutter build apk --release --split-per-abi --dart-define-from-file=env/dev.json
```

APK output:
`build/app/outputs/flutter-apk/`

## ৩) Real ফোনে অবশ্যই চেক করবেন
- Phone এবং PC একই WiFi/LAN এ আছে কিনা
- Windows Firewall এ port allow: **3000**, **9000**
- MinIO bucket যেগুলো থেকে ছবি/ভিডিও দেখায় সেগুলো **Read Only Public** করুন (MinIO Console -> Buckets -> Access -> Anonymous Read Only)

## ৪) Upload (Real Device) Note
Real device এ picker অনেক সময় `content://` URI দেয়—এই version এ multipart upload helper দিয়ে সেটা support করা হয়েছে।
