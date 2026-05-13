# BillMed

> Distributor bill payment tracker for medical retail shops. Fully offline Android app.

Track purchase bills from distributors, mark payments (Cash/UPI/Cheque/NEFT/RTGS), and always know exactly how much is pending with which supplier. No internet required. All data stays on device.

---

## Features

- **Supplier Management** — Add, search, edit, delete distributors
- **Bill Tracking** — Record bills with auto status: Unpaid → Partial → Paid
- **Payment Tracking** — 5 modes: Cash, UPI, Cheque, NEFT, RTGS with reference numbers
- **Dashboard** — Real-time summary, total billed/paid/pending, supplier-wise balances
- **Overdue Warnings** — Red badges on 30+ day unpaid bills, notification reminders
- **Dark Mode** — Toggle between Light, Dark, or System default
- **Search & Filter** — Search by bill number or supplier, filter by status, date range, sort by date/amount/status
- **OCR Bill Scan** — Take photo or pick from gallery → auto-fill bill number, date, amount
- **Reports** — Monthly turnover, collection rate, distributor breakdown, bar chart
- **PDF Export** — Generate and share bill PDFs with payment history
- **CSV Export** — Export all data as CSV files for backup
- **Bank Statement Import** — PDF parser with golden rule verification, manual entry fallback
- **Auto Backup** — Android Auto Backup syncs to Google Drive
- **Manual Backup** — Export/restore database file
- **Auto Updates** — In-app update checker, prompts when new version available
- **APK Obfuscation** — Code obfuscation to prevent reverse engineering

---

## Screens

| Tab | Content |
|-----|---------|
| **Dashboard** | Summary cards (billed/paid/pending), count chips (suppliers/bills/paid), overdue banner, distributor list with pending amounts |
| **Bills** | All bills with search bar, date range filter, status filter, sort (date/amount/status). Scan button for OCR. Red "OVERDUE" badge on unpaid bills >30 days |
| **Suppliers** | All distributors with search, pending amounts. Long press for edit/delete |
| **Settings** | Theme (light/dark/system), reports with bar chart, bank statement import, CSV export, manual backup/restore |

---

## Build

Requirements: Flutter SDK 3.x, Android SDK, Java 17.

```bash
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --obfuscate --split-debug-info=debug-info
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

Every push to `main` triggers an automatic build via GitHub Actions.  
Latest release: [github.com/krsnaSuraj/BillMed/releases/latest](https://github.com/krsnaSuraj/BillMed/releases/latest)

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
| Obfuscation | Flutter --obfuscate |
| Min SDK | Android 6.0 |

---

## Project Structure

```
BillMed/
├── lib/
│   ├── main.dart                    # App entry + navigation
│   ├── database/                    # SQLite tables + CRUD
│   ├── providers/                   # Riverpod state
│   ├── services/                    # Update, export, backup, PDF, OCR, bank parser
│   ├── screens/
│   │   ├── dashboard/               # Home
│   │   ├── bills/                   # List, add, detail
│   │   ├── distributors/            # List, add, detail
│   │   ├── payments/                # Add payment
│   │   ├── reports/                 # Reports + chart
│   │   ├── settings/                # Settings
│   │   ├── scanner/                 # OCR scan
│   │   └── bank_import/             # Bank PDF + manual entry
│   ├── models/enums.dart
│   └── theme/                       # Light + dark
├── android/                         # Android config
├── .github/workflows/build.yml      # CI
├── UPDATE.bat                       # One-click push & build
└── pubspec.yaml
```

---

## Database Schema

```
distributors: id, name, company, phone, created_at
bills:        id, distributor_id, bill_number, bill_date, amount, notes, created_at
payments:     id, bill_id, payment_date, amount, mode, reference_no, notes, created_at
bank_transactions: id, txn_date, description, debit, credit, balance, source_file, category, imported_at
```

Bill status is computed: `SUM(payments.amount)` vs `bills.amount` → Unpaid / Partial / Paid.

---

## Version

**v2.2.2** — [All Releases](https://github.com/krsnaSuraj/BillMed/releases)
