# BillMed

Distributor bill payment tracker for medical retail shops.

Track distributor bills, payments, and pending amounts — fully offline on Android.

---

## Features

| Feature | Description |
|---------|-------------|
| **Supplier Management** | Add, search, edit, delete distributors |
| **Bill Tracking** | Record bills with auto status (Unpaid/Partial/Paid) |
| **Payment Tracking** | Cash, UPI, Cheque, NEFT, RTGS — 5 modes |
| **Dashboard** | Summary cards, counts, overdue alerts |
| **Dark Mode** | Light, Dark, System auto |
| **Search & Filter** | By bill number, supplier, date range, status, sort |
| **OCR Scan** | Camera/gallery bill scan with auto-fill |
| **Reports** | Monthly turnover with bar chart, distributor breakdown |
| **PDF Export** | Generate and share bill PDFs |
| **CSV Export** | Export all data as CSV |
| **Bank Statement Import** | PDF parser with golden rule verification + manual entry |
| **Backup** | Android Auto Backup + manual DB backup/restore |
| **Notifications** | Overdue bill reminders |
| **APK Obfuscation** | Code obfuscation enabled |
| **Auto Updates** | In-app update checker |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.41 (Dart) |
| Database | Drift (SQLite ORM) |
| State | Riverpod |
| OCR | Google ML Kit (on-device) |
| Charts | fl_chart |
| CI/CD | GitHub Actions |
| Min SDK | Android 6.0 |
| APK Size | 88 MB |

---

## Build

```bash
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --obfuscate --split-debug-info=debug-info
```

---

## Project Structure

```
BillMed/
├── lib/
│   ├── main.dart
│   ├── database/                          # SQLite + CRUD
│   ├── providers/                         # Riverpod state
│   ├── services/                          # Update, export, backup, PDF, OCR, bank parser
│   ├── screens/
│   │   ├── dashboard/                     # Home
│   │   ├── bills/                         # List, add, detail
│   │   ├── distributors/                  # List, add, detail
│   │   ├── payments/                      # Add payment
│   │   ├── reports/                       # Reports + chart
│   │   ├── settings/                      # Settings
│   │   ├── scanner/                       # OCR scan
│   │   └── bank_import/                   # Bank PDF + manual entry
│   ├── models/enums.dart
│   └── theme/                             # Light + dark
├── android/                               # Android config
├── .github/workflows/build.yml            # CI
├── UPDATE.bat
└── pubspec.yaml
```

---

## Version

`v2.2.2` — [View Releases](https://github.com/krsnaSuraj/BillMed/releases)
