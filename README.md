# BillMed

Distributor bill payment tracker for medical retail shops. Fully offline Android application with optional AI enhancement via Gemini.

---

## Features

| Category | Details |
|----------|---------|
| **Supplier Management** | Add, search, edit, delete distributors with name, company, phone |
| **Bill Tracking** | Record bills with auto status: Unpaid → Partial → Paid |
| **Payment Tracking** | 5 modes: Cash, UPI, Cheque, NEFT, RTGS with reference numbers |
| **Dashboard** | Summary cards, supplier-wise balances, overdue alerts, count chips |
| **Search & Filter** | By bill number, supplier, date range, status filter, sort by date/amount/status |
| **OCR Scan** | Camera/gallery → auto-fill bill number, date, amount |
| **AI Enhancement** | Optional Gemini API key in Settings — corrects OCR, parses bank PDFs |
| **Reports** | Monthly turnover, collection rate, bar chart, distributor breakdown |
| **CA Report** | Yearly credit/debit summary with monthly breakdown, CSV + PDF export |
| **Bank Statement Import** | PDF parser with golden rule verification; AI parsing if API key provided; manual entry fallback |
| **View Bank Transactions** | Browse imported transactions with search, debit/credit summary |
| **PDF Export** | Generate and share bill PDFs with payment history |
| **CSV Export** | Distributors, bills, payments, bank transactions — individual or all |
| **Backup** | Auto backup on app close, Android Auto Backup (Google Drive), manual DB backup/restore |
| **Notifications** | Overdue bill reminders on app launch |
| **Dark Mode** | Light, Dark, or System auto |
| **Auto Updates** | Checks GitHub for new versions, prompts update |
| **APK Obfuscation** | Code obfuscation enabled |

---

## Security & Privacy

| Concern | How It's Handled |
|---------|-----------------|
| **API key safety** | User provides own key via Settings → stored in app storage. NOT in code/repo. |
| **Data privacy** | 100% offline. No data leaves the device. |
| **Backup** | Auto backup to Downloads folder — no cloud required. |
| **APK safety** | Code obfuscation enabled — reverse engineering difficult. |

---

## AI Integration (Optional)

BillMed supports Google Gemini for enhanced parsing:

- **Bank statement import**: Send PDF text to Gemini for structured extraction
- **OCR correction**: Gemini fixes common OCR recognition errors
- **Multi-model fallback**: Automatically switches between gemini-2.0-flash, 1.5-flash, 1.5-flash-8b on rate limit
- **No key? No problem**: Falls back to regex parser and manual entry

### How to get a free API key

1. Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Click "Create API Key" (free, 60 requests/minute)
3. Open BillMed → Settings → Gemini API Key → Paste key

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

| Tab | Content |
|-----|---------|
| **Dashboard** | Summary cards (billed/paid/pending), overdue banner, count chips, distributor balances |
| **Bills** | Full list with search, date range, status filter, sort. OCR scan button. Overdue badges. |
| **Suppliers** | Searchable list with pending amounts. Long press for edit/delete. |
| **Settings** | Theme toggle, Gemini API key, reports, CA report, bank import, bank transactions view, CSV export, backup/restore |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.41 (Dart) |
| Database | Drift (SQLite ORM) |
| State Management | Riverpod |
| OCR | Google ML Kit (on-device, no API key) |
| AI | Google Gemini (optional, user-provided key) |
| Charts | fl_chart |
| CI/CD | GitHub Actions |
| Obfuscation | Flutter --obfuscate |
| Minimum SDK | Android 6.0 (API 23) |
| APK Size | 89 MB |

---

## Project Structure

```
BillMed/
├── lib/
│   ├── main.dart                    # App entry, 4-tab navigation, lifecycle
│   ├── database/                    # Tables, CRUD, DAO, schema migrations
│   ├── providers/                   # Riverpod (DB, theme, Gemini key)
│   ├── services/                    # Update, backup, export, PDF, OCR, bank parser, notifications, Gemini
│   ├── screens/
│   │   ├── dashboard/               # Home
│   │   ├── bills/                   # List, add, detail
│   │   ├── distributors/            # List, add, detail
│   │   ├── payments/                # Add/edit payment
│   │   ├── reports/                 # Reports + bar chart
│   │   ├── reports/yearly_report    # CA yearly report
│   │   ├── settings/                # Settings + AI key
│   │   ├── scanner/                 # OCR bill scanner
│   │   └── bank_import/             # PDF import, manual entry, bank view
│   ├── models/                      # Enums
│   └── theme/                       # Light + dark theme
├── android/                         # Android configuration
├── .github/workflows/build.yml      # CI
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

## Version

**v2.3.0** — [All Releases](https://github.com/krsnaSuraj/BillMed/releases)
