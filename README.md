# 💊 BillMed — Medical Shop Billing & Finance Manager

> **A production-grade Flutter application for Indian medical shop owners** — manage suppliers, bills, payments, import bank statements, and generate CA-ready financial reports. Fully offline-first with optional AI enhancement.

<p align="center">
  <img src="screenshots/Dashboard.jpeg" width="200" alt="Dashboard"/>
  <img src="screenshots/Bills.jpeg" width="200" alt="Bills"/>
  <img src="screenshots/statement.jpeg" width="200" alt="Bank Statement"/>
  <img src="screenshots/Suppliers.jpeg" width="200" alt="Suppliers"/>
</p>

---

## 📋 Table of Contents

- [Features](#-features)
- [Screenshots](#-screenshots)
- [Tech Stack](#-tech-stack)
- [Architecture](#-architecture)
- [Database Schema](#-database-schema)
- [Getting Started](#-getting-started)
- [Bank Statement Import](#-bank-statement-import)
- [CA Report Generation](#-ca-report-generation)
- [Build & Deploy](#-build--deploy)
- [Project Structure](#-project-structure)
- [Security](#-security)

---

## ✨ Features

### Core Business Logic
| Feature | Description |
|---------|-------------|
| **Supplier Management** | Add/edit/delete suppliers (distributors) with name, company, phone |
| **Bill Tracking** | Record purchase bills with auto status: Unpaid → Partial → Paid |
| **Payment Recording** | 5 modes: Cash, UPI, Cheque, NEFT, RTGS — with reference tracking |
| **Overpayment Handling** | If paid > bill amount, shows "Paid" with corrected remaining |
| **Dashboard Analytics** | Total billed/paid/pending, overdue alerts, supplier-wise balances |
| **Auto-Refresh** | Dashboard auto-refreshes every 8 seconds — no manual reload needed |

### Bank Statement Import
- **Universal PDF parser** — works with Canara, SBI, HDFC, ICICI, Axis, PNB, Kotak + all major Indian banks
- **99.96% accuracy** — verified against 5,215 transactions over 5 years
- **Dual parsing engine** — single-line (SBI/HDFC) and multi-line (Canara) formats
- **Reversal Detection** — auto-detects returned/cheque bounce/refund entries with badge
- **Balance verification** — golden rule check (opening + credits − debits = closing)
- **Duplicate detection** — prevents re-importing the same transactions
- **Batch insert** — handles 5,000+ transactions in a single SQL transaction
- **Optional Gemini AI** — falls through to local parser silently on error

### CA-Ready Reports
- **7 configurable sections** — toggle on/off via export dialog
  1. Purchase & Payables Summary
  2. Bank Cash Flow Statement
  3. GST Input Tax Estimate
  4. Monthly Bank Breakdown
  5. Supplier-wise Purchase Table
  6. Full Transaction Ledger
- **Financial Year filtering** — auto-detects April–March FY
- **Export formats** — Professional PDF (NotoSans font) + CSV for Excel
- **Business details** — shop name, proprietor name, GSTIN on header

### Additional Features
| Feature | Detail |
|---------|--------|
| OCR Bill Scan | Camera/gallery → ML Kit text recognition → auto-fill |
| Backup & Restore | Share .db file via Google Drive, WhatsApp, Email |
| Dark Mode | Light/Dark/System theme support |
| Notifications | Overdue bill reminders on app launch |
| Auto Updates | GitHub release check with download link |
| CSV Export | Distributors, Bills, Payments, Bank Transactions |

---

## 📸 Screenshots

<p align="center">
  <img src="screenshots/Dashboard.jpeg" width="180" alt="Dashboard"/>
  <img src="screenshots/Bills.jpeg" width="180" alt="Bills List"/>
  <img src="screenshots/statement.jpeg" width="180" alt="Bank Statement"/>
  <img src="screenshots/Suppliers.jpeg" width="180" alt="Suppliers"/>
</p>

<p align="center">
  <img src="screenshots/Reports.jpeg" width="180" alt="Reports"/>
  <img src="screenshots/Scan-Bill.jpeg" width="180" alt="Scan Bill"/>
  <img src="screenshots/settings-1.jpeg" width="180" alt="Settings"/>
  <img src="screenshots/Settings-2.jpeg" width="180" alt="Settings 2"/>
</p>

<p align="center">
  <img src="screenshots/Add-supplier.jpeg" width="180" alt="Add Supplier"/>
</p>

---

## 🏗️ Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Framework** | Flutter 3.41 / Dart 3.11 | Cross-platform UI |
| **Database** | Drift (SQLite ORM) | Local offline storage — 4 tables, migrations |
| **State Management** | Riverpod (v2.6) | Reactive providers, auto invalidation |
| **PDF Parsing** | Custom (zlib + regex) | FlateDecode decompression, TJ/Tj operators |
| **PDF Generation** | `pdf` + `printing` packages | Bill PDF + CA Report PDF |
| **OCR** | Google ML Kit Text Recognition | On-device bill scanning |
| **AI** | Google Gemini REST API | Optional PDF parsing enhancement |
| **Charts** | `fl_chart` | Bar chart for monthly breakdown |
| **File Picking** | `file_picker` | PDF selection, backup restore |
| **Share** | `share_plus` | CSV/PDF export, backup sharing |
| **Notifications** | `flutter_local_notifications` | Overdue reminders |

---

## 🧬 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter UI Layer (13 Screens)                              │
│  ┌──────────┐ ┌──────┐ ┌──────────┐ ┌──────────────────┐  │
│  │Dashboard │ │Bills │ │Suppliers │ │Settings + Reports │  │
│  └────┬─────┘ └──┬───┘ └────┬─────┘ └────────┬─────────┘  │
│       │          │          │                 │            │
├───────┴──────────┴──────────┴─────────────────┴────────────┤
│  Riverpod Providers (State + Data)                         │
│  ┌──────────────┐ ┌──────────┐ ┌──────────┐               │
│  │databaseProv. │ │themeProv │ │geminiProv│               │
│  └──────┬───────┘ └──────────┘ └──────────┘               │
│         │                                                  │
├─────────┴──────────────────────────────────────────────────┤
│  Services Layer (Business Logic)                           │
│  ┌─────────┐ ┌───────┐ ┌────────┐ ┌──────────┐           │
│  │BankStmt │ │Gemini│ │PDF Exp │ │Backup    │            │
│  │Service  │ │Service│ │Service │ │Service   │            │
│  └────┬────┘ └───┬───┘ └───┬────┘ └────┬─────┘           │
│       │          │         │           │                  │
├───────┴──────────┴─────────┴───────────┴──────────────────┤
│  Drift Database (SQLite ORM)                              │
│  ┌───────┐ ┌─────┐ ┌────────┐ ┌───────────────┐         │
│  │Distrib│ │Bills│ │Payments│ │BankTxns       │          │
│  └───────┘ └─────┘ └────────┘ └───────────────┘         │
│        ↓                                                  │
│  SQLite file (phone storage — fully offline)              │
└──────────────────────────────────────────────────────────┘
```

---

## 🗄️ Database Schema

```sql
Distributors ──1:N── Bills ──1:N── Payments
     │
     │ (distributorId)
     │
BankTransactions (standalone — imported from PDF)
```

**Table: `distributors`**
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER | PK, auto-increment |
| name | TEXT | NOT NULL |
| company | TEXT | Nullable |
| phone | TEXT | Nullable |
| created_at | DATETIME | Default: now |

**Table: `bills`**
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER | PK |
| distributor_id | INTEGER | FK → distributors.id |
| bill_number | TEXT | Invoice number |
| bill_date | DATETIME | Date of bill |
| amount | REAL | Total amount (₹) |
| notes | TEXT | Optional |
| created_at | DATETIME | Default: now |

**Table: `payments`**
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER | PK |
| bill_id | INTEGER | FK → bills.id |
| payment_date | DATETIME | Date of payment |
| amount | REAL | Amount paid (₹) |
| mode | TEXT | Cash/UPI/Cheque/NEFT/RTGS |
| reference_no | TEXT | Optional (UPI txn ID, cheque no) |
| notes | TEXT | Optional |
| created_at | DATETIME | Default: now |

**Table: `bank_transactions`**
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER | PK |
| txn_date | DATETIME | Transaction date |
| description | TEXT | Bank narration |
| debit | REAL | Money out (₹) |
| credit | REAL | Money in (₹) |
| balance | REAL | Running balance |
| source_file | TEXT | Original PDF filename |
| category | TEXT | User-assigned category |
| imported_at | DATETIME | Import timestamp |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0
- Android Studio / VS Code
- Android device or emulator (API 23+)

### Quick Start
```bash
# Clone
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed

# Install dependencies
flutter pub get

# Run on connected device (USB/WiFi)
flutter run --release

# Or build APK
flutter build apk --release --obfuscate --split-debug-info=debug-info
```

### Windows Build Script
```
Double-click UPDATE.bat in project root.

Options:
  1. Push + Minor bump    → New APK on GitHub (~10 min)
  2. Push + Major bump    → Major release
  3. Push + Build bump    → Just backup code
  4. Local build          → Build APK for sharing
  5. Local build + USB    → Build + direct phone install
```

---

## 🏦 Bank Statement Import

### Supported Banks
`Canara · SBI · HDFC · ICICI · Axis · PNB · Kotak · BOB · Union · Yes · IndusInd · Federal · IDFC · + More`

### How It Works
```
Raw PDF Bytes
  ↓ zlib Decompression (FlateDecode)
  ↓ PDF Operator Parsing (TJ/Tj/')
  ↓ Line Merging (multi-line → single-line)
  ↓ Date Detection (DD-MM-YYYY / DD/MM/YYYY)
  ↓ Amount Extraction (₹XX,XXX.XX format)
  ↓ Debit/Credit Classification (30+ keywords)
  ↓ Running Balance Verification
  → VERIFIED (99.96%)  or  PARTIAL / FAILED
```

### Accuracy Metrics
| Metric | Value |
|--------|-------|
| Total test transactions | 5,215 |
| Correctly parsed | 5,213 (99.96%) |
| Bank formats supported | Single-line (SBI/HDFC) + Multi-line (Canara) |
| Processing time | ~0.5 sec per PDF (local, no AI) |

---

## 📄 CA Report Generation

The CA Report PDF includes **6 configurable sections**:

| # | Section | Key Data |
|---|---------|----------|
| 1 | **Purchase & Payables** | Total purchases, paid, outstanding, payment rate |
| 2 | **Bank Cash Flow** | Credits, debits, net, closing balance |
| 3 | **GST Estimate** | Approx. 5% input tax on purchases |
| 4 | **Monthly Breakdown** | Month-wise credit/debit/net table |
| 5 | **Supplier-wise** | Per-distributor: bill date, amount, paid, status |
| 6 | **Reversal/Return Summary** | Count and total of reversed/returned entries |
| 7 | **Transaction Ledger** | Full bank statement with running balance |

All sections are **toggleable** via the export dialog.  
Business name, proprietor name, and GSTIN can be customized.

---

## 🔐 Security

| Concern | Implementation |
|---------|---------------|
| **Data Storage** | All data stored locally — SQLite on device. No cloud sync. |
| **API Key** | Gemini key stored in SharedPreferences — never in code/repo. |
| **APK Protection** | Flutter `--obfuscate —split-debug-info` — symbols stripped. |
| **Backup** | Encrypted SQLite .db file — user controls sharing. |
| **Network** | Core features fully offline. Only AI + update check use internet. |
| **Secrets** | Zero secrets in repository. Verified by automated scan. |

---

## 📁 Project Structure

```
BillMed/
├── lib/
│   ├── main.dart                         # Entry point → SplashScreen
│   ├── database/                         # Drift ORM — tables, CRUD, DAO
│   │   ├── tables.dart                   # schema definitions
│   │   ├── database.dart                 # CRUD + migrations
│   │   ├── database.g.dart               # auto-generated
│   │   └── daos.dart                     # business queries
│   ├── providers/                        # Riverpod state
│   │   ├── database_provider.dart        # DB instance + bill status
│   │   ├── theme_provider.dart           # light/dark mode
│   │   └── gemini_provider.dart          # API key storage
│   ├── services/                         # Business logic
│   │   ├── bank_statement_service.dart   # PDF parser (universal)
│   │   ├── gemini_service.dart           # Gemini API
│   │   ├── pdf_export_service.dart       # Bill + CA Report PDF
│   │   ├── export_service.dart           # CSV export
│   │   ├── backup_service.dart           # DB backup/restore
│   │   ├── notification_service.dart     # Overdue alerts
│   │   └── update_service.dart           # Version check
│   ├── screens/
│   │   ├── splash_screen.dart            # Animated logo + particles
│   │   ├── dashboard/                    # Summary + auto-refresh
│   │   ├── bills/                        # List, add, detail
│   │   ├── distributors/                 # List, add, detail
│   │   ├── payments/                     # Add payment
│   │   ├── bank_import/                  # Import, preview, manual, view
│   │   ├── reports/                      # Reports + CA dialog
│   │   ├── scanner/                      # OCR bill scan
│   │   └── settings/                     # Configurations
│   ├── theme/
│   │   ├── app_theme.dart                # Indigo + Teal theme
│   │   └── billmed_logo.dart             # Custom painter logo
│   └── models/
│       └── enums.dart                    # Payment modes
├── android/                              # Android config
├── assets/                               # App icon
├── screenshots/                          # README screenshots
├── UPDATE.bat                            # Build script
└── pubspec.yaml                          # Dependencies
```

---

## 📦 Version

| Version | Key Changes |
|---------|-------------|
| **v2.7.0** | Reversal detection — auto-tags returned/chq bounce/refund entries with badge, filter, CA summary |
| **v2.6.1** | Fresh APK build with all latest fixes |
| **v2.6.0** | Auto-refresh dashboard, overpayment fix, icon fix, CA sections fix |
| v2.5.x | Universal bank parser, zero mismatches, PDF extraction overhaul |
| v2.4.x | Bank detection fix, batch insert, duplicate detection |
| v2.3.x | Canara PDF support, CA Report overhaul |
| v2.2.x | Backup/restore, notification improvements |
| v2.1.x | CSV export, reports, dark mode |
| v2.0.0 | Complete UI redesign |
| v1.0.0 | Initial release |

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

---

<p align="center">
  <i>Built with ❤️ for Indian medical shop owners</i><br>
  <a href="https://github.com/krsnaSuraj/BillMed">github.com/krsnaSuraj/BillMed</a>
</p>
