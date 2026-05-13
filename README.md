# BillMed

Distributor bill payment tracker for medical retail shops.

Track distributor bills, payments, and pending amounts — fully offline on Android.

## Features

- Add and manage distributors (suppliers)
- Record purchase bills from distributors
- Mark payments against bills (Cash / UPI / Cheque / NEFT / RTGS)
- Auto-calculated bill status: Unpaid → Partial → Paid
- Dashboard with real-time pending amount summary per distributor
- 100% offline — no internet connection required
- Android Auto Backup — data automatically saved to Google Drive
- Share backup via WhatsApp or any sharing app
- Large fonts and simple UI for easy daily use

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| Database | Drift (SQLite ORM) |
| State Management | Riverpod |
| Backup | Android Auto Backup (Google Drive) |
| Min SDK | Android 6.0+ |

## Build APK

```bash
# Prerequisites: Flutter SDK installed
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed

# Install dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# Build release APK
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Installation on Device

1. Transfer the APK file to the Android device (via WhatsApp, Google Drive, USB, etc.)
2. Open the APK file on the device
3. Enable "Install from unknown sources" when prompted
4. Complete installation

## Project Structure

```
lib/
├── main.dart                          # App entry point with bottom navigation
├── database/
│   ├── tables.dart                    # Drift table definitions
│   ├── database.dart                  # Database class with CRUD operations
│   └── daos.dart                      # Business logic and query helpers
├── models/enums.dart                  # Payment mode enum
├── providers/database_provider.dart   # Riverpod state providers
├── screens/
│   ├── dashboard/dashboard_screen.dart
│   ├── distributors/
│   │   ├── distributor_list_screen.dart
│   │   ├── add_distributor_screen.dart
│   │   └── distributor_detail_screen.dart
│   ├── bills/
│   │   ├── add_bill_screen.dart
│   │   └── bill_detail_screen.dart
│   └── payments/add_payment_screen.dart
├── widgets/
│   ├── status_badge.dart
│   └── empty_state.dart
└── theme/app_theme.dart
```

## License

MIT
