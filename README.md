# BillMed

Distributor bill payment tracker for medical retail shops. Offline-first Android application with optional AI enhancement via Google Gemini.

---

## Overview

Record purchase bills from distributors, mark payments (Cash/UPI/Cheque/NEFT/RTGS), import bank statements, and track pending amounts per supplier. Core features work fully offline. AI features (bank PDF parsing, OCR correction) require an optional Gemini API key.

---

## Features

| Category | Features |
|----------|----------|
| **Suppliers** | Add, search, edit, delete. View pending amounts in list. |
| **Bills** | Record with auto status: Unpaid → Partial → Paid. Search, filter by status/date/sort. |
| **Payments** | 5 modes: Cash, UPI, Cheque, NEFT, RTGS. Reference number tracking. |
| **Dashboard** | Summary cards, supplier-wise balances, overdue alerts with red badges. |
| **OCR Scan** | Camera or gallery → auto-fill bill number, date, amount. |
| **Bank Import** | PDF parser with golden rule verification. AI parsing available with Gemini key. |
| **Reports** | Monthly turnover, bar chart, collection rate, distributor breakdown. |
| **CA Report** | Yearly credit/debit summary, monthly breakdown, PDF + CSV export. |
| **Bank Transactions** | Browse imported transactions with search and credit/debit stats. |
| **Bill PDF** | Generate and share bill PDFs with payment history. |
| **CSV Export** | Export suppliers, bills, payments, or bank transactions. |
| **Backup** | Auto backup on app close. Manual DB backup and restore. |
| **Dark Mode** | Light, Dark, or System default. |
| **Notifications** | Overdue bill reminders on app launch. |
| **Auto Updates** | Checks GitHub Releases for new versions. |

---

## Screens

| Tab | Content |
|-----|---------|
| **Dashboard** | Summary (billed/paid/pending), overdue banner, count chips, supplier list with balances |
| **Bills** | Full list with search, date range, status filter, 3-way sort, OCR scan, overdue badges |
| **Suppliers** | Searchable list with pending amounts. Long press for edit/delete. |
| **Settings** | Theme, Gemini API key, reports, CA report, bank import, bank transactions, CSV export, backup |

---

## AI Integration (Optional)

BillMed supports Google Gemini for improved accuracy. The API key is entered by the user in Settings and stored locally. It is never included in the source code.

### What AI Improves

| Feature | Without AI | With AI |
|---------|-----------|---------|
| Bank statement import | Regex parser (limited format support) | Gemini extracts transactions from any format |
| OCR bill scan | Regex parsing of text | Gemini corrects recognition errors |

### Multi-Model Fallback

When using AI, the app automatically switches between models if rate limits are hit:
`gemini-2.0-flash` → `gemini-1.5-flash` → `gemini-1.5-flash-8b`

If all models fail or no key is provided, the app falls back to the built-in regex parser or manual entry.

### Getting a Free API Key

1. Visit [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Click "Create API Key" — free tier includes 60 requests per minute
3. Open BillMed → Settings → Gemini API Key → paste key

---

## Security

| Concern | Handling |
|---------|----------|
| API key exposure | Key stored in app preferences, NOT in code or repository |
| Data privacy | Bank statements processed on-device or via user's own API key |
| Network usage | Core features work offline. AI features require internet. |
| APK protection | Code obfuscation enabled via Flutter `--obfuscate` |
| Secrets in repo | None. Verified by scan. |

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

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.41.9 (Dart 3.11) |
| Database | Drift (SQLite ORM) |
| State | Riverpod |
| OCR | Google ML Kit (on-device) |
| AI | Google Gemini (user-provided key) |
| Charts | fl_chart |
| CI/CD | GitHub Actions |
| Obfuscation | Flutter `--obfuscate` |
| Min SDK | Android 6.0 (API 23) |
| APK Size | ~89 MB |

---

## Project Structure

```
BillMed/
├── lib/
│   ├── main.dart                    # Entry, 4-tab nav, lifecycle
│   ├── database/                    # Tables, CRUD, DAO, migrations
│   ├── providers/                   # DB, theme, Gemini key
│   ├── services/                    # Update, export, backup, PDF, OCR, bank parser, notifications, Gemini
│   ├── screens/
│   │   ├── dashboard/               # Home
│   │   ├── bills/                   # List, add, detail
│   │   ├── distributors/            # List, add, detail
│   │   ├── payments/                # Add/edit payment
│   │   ├── reports/                 # Reports + chart
│   │   ├── reports/yearly_report    # CA yearly report
│   │   ├── settings/                # Settings + AI key
│   │   ├── scanner/                 # OCR scanner
│   │   └── bank_import/             # PDF import, manual entry, bank view
│   └── theme/                       # Light + dark theme
├── android/                         # Android config + backup rules
├── .github/workflows/build.yml      # Auto-build on push
├── UPDATE.bat                       # Local build/push
└── pubspec.yaml                     # Dependencies
```

---

## Version History

| Version | Key Changes |
|---------|-------------|
| v2.3.4 | CA Report PDF: full transaction list with opening/closing balance, CSV-compatible |
| v2.3.3 | Canara bank statement fix: line merging, UPI/CR keyword corrected |
| v2.3.2 | Fix bank parser: integer amounts, credit detection, stricter balance checks |
| v2.3.1 | Release build — all fixes included, CI/CD release fix |
| v2.3.0+2 | Fixed 14 analyzer warnings, improved PDF parser (FlateDecode+zlib), BuildContext safety |
| v2.3.0 | Gemini AI integration, bank transactions view, CA report PDF, backup fixes |
| v2.2.2 | Bug fixes: backup crash, notification ID, N+1 query, DB leak |
| v2.2.0 | Bank statement import with golden rule verification |
| v2.1.0 | CSV export, reports screen, dark mode, search, filter |
| v2.0.0 | Complete UI redesign, 4-tab navigation |
| v1.0.0 | Initial release |

---

## License

MIT
