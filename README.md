# BillMed

Distributor bill payment tracker for medical retail shops.

Track distributor bills, payments, and pending amounts — fully offline on Android.

## Features

- Add and manage distributors (suppliers)
- Record purchase bills from distributors
- Mark payments against bills (Cash / UPI / Cheque / NEFT / RTGS)
- Auto-calculated bill status: Unpaid → Partial → Paid
- Dashboard with real-time pending amount summary per distributor
- In-app update checker — pops up when new version is available
- 100% offline — no internet connection required
- Android Auto Backup — data automatically saved to Google Drive
- Large fonts and simple UI for elderly users
- APK code obfuscation enabled

## Build APK (Local)

```bash
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --obfuscate --split-debug-info=debug-info
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Auto Build (GitHub Actions)

Every push to `main` branch triggers an automatic build.
Latest APK: https://github.com/krsnaSuraj/BillMed/releases/latest

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| Database | Drift (SQLite ORM) |
| State Management | Riverpod |
| Updates | GitHub Actions + in-app checker |
| Obfuscation | Flutter --obfuscate + ProGuard |
| Min SDK | Android 6.0+ |

## Project Structure

```
lib/
├── main.dart                          # App entry + update check
├── database/
│   ├── tables.dart                    # Drift table definitions
│   ├── database.dart                  # CRUD operations
│   └── daos.dart                      # Dashboard business logic
├── models/enums.dart                  # Payment mode enum
├── providers/database_provider.dart   # Riverpod providers
├── services/update_service.dart       # In-app update checker
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
