# BillMed 🏥📊

Distributor bill payment tracker for medical retail shops.

Track distributor bills, payments, and pending amounts — all offline on your Android phone.

## Features

- Add distributors (suppliers)
- Record bills received from distributors
- Mark payments against bills (Cash / UPI / Cheque / NEFT / RTGS)
- Auto-calculates bill status: Unpaid → Partial → Paid
- Home dashboard with pending amount summary
- 100% offline — no internet required
- Android Auto Backup (data safe on Google Drive)
- Share backup via WhatsApp

## For Papa

1. App install karein
2. Distributor add karein (Sterling, Alkem, etc.)
3. Bill aaye to "Add Bill" me bill no. + amount daalein
4. Paisa diya to "Add Payment" me payment mark karein
5. Dashboard pe pata chalega kis Distributor ke kitne paise bakaya hai

## Build APK

```bash
flutter pub get
flutter build apk --release
```

APK file: `build/app/outputs/flutter-apk/app-release.apk`

## Tech Stack

- **Flutter 3.x** (Dart)
- **Drift** (SQLite ORM)
- **Riverpod** (State management)
- **Android Auto Backup** (Google Drive)

## License

MIT
