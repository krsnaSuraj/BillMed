# BillMed

Distributor bill payment tracker for medical retail shops. Fully offline Android application.

Track purchase bills from distributors and wholesalers. Record incoming bills, mark payments against them, and know exactly how much is pending with each supplier. No internet required. All data stays on the device.

---

## Features

| Category | Features |
|----------|----------|
| **Supplier Management** | Add, search, edit, delete distributors with name, company, phone |
| **Bill Tracking** | Record bills with auto status: Unpaid → Partial → Paid |
| **Payment Tracking** | 5 modes: Cash, UPI, Cheque, NEFT, RTGS with reference numbers |
| **Dashboard** | Real-time summary cards, supplier-wise balances, overdue alerts |
| **Search & Filter** | By bill number, supplier name, date range, status, sort by date/amount/status |
| **OCR Scan** | Camera or gallery photo → auto-fill bill number, date, amount |
| **Reports** | Monthly turnover, collection rate, distributor breakdown, bar chart |
| **CA Report** | Yearly credit/debit summary with monthly breakdown, CSV export |
| **PDF Export** | Generate and share bill PDFs with payment history |
| **CSV Export** | Export distributors, bills, payments, bank transactions individually or all |
| **Bank Statement Import** | PDF parser with golden rule verification, manual entry fallback |
| **Backup** | Auto backup on app close, Android Auto Backup (Google Drive), manual DB backup/restore |
| **Notifications** | Overdue bill reminders on app launch |
| **Dark Mode** | Light, Dark, or System default |
| **Auto Updates** | Checks GitHub for new versions, prompts update |
| **APK Obfuscation** | Code obfuscation enabled to prevent reverse engineering |

---

## Build

```bash
# Requirements: Flutter 3.x, Android SDK, Java 17
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

## Screens

| Tab | Description |
|-----|-------------|
| **Dashboard** | Summary cards (billed/paid/pending), overdue banner, count chips, distributor balances |
| **Bills** | Full list with search, date range, status filter, sort. OCR scan button. Overdue badges |
| **Suppliers** | Searchable list with pending amounts. Long press for edit/delete |
| **Settings** | Theme toggle, reports, CA report, bank import, CSV export, backup/restore |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.41 (Dart) |
| Database | Drift (SQLite ORM) |
| State Management | Riverpod |
| OCR | Google ML Kit (on-device, no API key) |
| Charts | fl_chart |
| CI/CD | GitHub Actions |
| Obfuscation | Flutter --obfuscate |
| Minimum SDK | Android 6.0 (API 23) |
| APK Size | 88.5 MB |

---

## Project Structure

```
BillMed/
├── lib/
│   ├── main.dart                    # App entry, 4-tab navigation, lifecycle
│   ├── database/                    # Tables, CRUD, DAO, migrations
│   ├── providers/                   # Riverpod state providers
│   ├── services/                    # Update, backup, export, PDF, OCR, bank parser, notifications
│   ├── screens/
│   │   ├── dashboard/               # Home screen
│   │   ├── bills/                   # Bill list, add, detail
│   │   ├── distributors/            # Supplier list, add, detail
│   │   ├── payments/                # Add/edit payment
│   │   ├── reports/                 # Reports + bar chart
│   │   ├── reports/yearly_report    # CA yearly report
│   │   ├── settings/                # Settings
│   │   ├── scanner/                 # OCR bill scanner
│   │   └── bank_import/             # PDF import + manual entry
│   ├── models/                      # Enums, types
│   └── theme/                       # Light + dark theme
├── android/                         # Android configuration
├── .github/workflows/build.yml      # GitHub Actions CI
├── UPDATE.bat                       # Local build/push script
└── pubspec.yaml                     # Dependencies
```

---

## Database Schema

```
distributors:      id, name, company, phone, created_at
bills:             id, distributor_id, bill_number, bill_date, amount, notes, created_at
payments:          id, bill_id, payment_date, amount, mode, reference_no, notes, created_at
bank_transactions: id, txn_date, description, debit, credit, balance, source_file, category, imported_at
```

Bill status is computed: `SUM(payments.amount)` vs `bills.amount` → Unpaid / Partial / Paid.

---

## Bugs Fixed

This codebase has undergone thorough code review. 18 issues were identified and fixed, including:

- **Critical**: Database connection not reopened after restore — app crash
- **High**: Hardcoded storage path failing on Android 11+, notification ID collision
- **Medium**: N+1 query in export, DB provider disposal leak, null crash on save
- **Low**: Dead code, unused parameters, layout overflow, premature provider invalidation

---

## Version

**v2.2.2** — [All Releases](https://github.com/krsnaSuraj/BillMed/releases)
