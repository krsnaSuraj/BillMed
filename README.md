# BillMed

> Distributor bill payment tracker for medical retail shops.

BillMed helps shopkeepers track purchase bills from distributors and wholesalers. Record incoming bills, mark payments against them, and always know exactly how much is pending with which supplier. Fully offline. No internet required.

---

## Features

| Feature | Description |
|---------|-------------|
| **Supplier Management** | Add distributors with name, company, phone |
| **Bill Tracking** | Record bills with number, date, amount |
| **Payment Tracking** | Mark payments — Cash / UPI / Cheque / NEFT / RTGS |
| **Auto Status** | Bills auto-tag as Unpaid / Partial / Paid |
| **Dashboard** | Real-time summary of total billed, paid, pending |
| **Dark Mode** | Toggle between light and dark themes |
| **Search & Filter** | Search bills by number or supplier name; filter by status |
| **CSV Export** | Export all data to CSV — share via WhatsApp, email, or save |
| **Reports** | View summary and per-distributor breakdown |
| **Auto Backup** | Android Auto Backup syncs data to Google Drive |
| **Auto Updates** | App checks for new versions and prompts to update |
| **Obfuscated APK** | Code obfuscation prevents reverse engineering |
| **100% Offline** | No internet required. Data stays on device |

---

## Navigation

App has 4 tabs:

| Tab | Content |
|-----|---------|
| **Dashboard** | Summary cards: total billed, paid, pending. List of all distributors with pending amounts. Tap to drill into bills. |
| **Bills** | All bills with search bar and status filter chips. Tap a bill to see details and payment history. FAB to add new bill. |
| **Suppliers** | All distributors listed. Tap to see their bills. FAB to add new supplier. |
| **Settings** | Dark mode toggle. Export data as CSV. View reports. App version. |

---

## How It Works

### Data Model

```
distributors --> bills --> payments
```

- **distributors**: id, name, company, phone
- **bills**: id, distributor_id, bill_number, bill_date, amount, notes
- **payments**: id, bill_id, payment_date, amount, mode, reference_no, notes

Bill status is computed automatically: if `SUM(payments)` equals `bill.amount`, the bill is marked Paid. If partial, Partial. If none, Unpaid.

### Workflow

1. Add a supplier (one-time setup)
2. When goods arrive with a bill, tap + and enter bill number, date, amount
3. When payment is made, tap the bill, tap Add Payment, select mode (Cash/UPI/Cheque/NEFT/RTGS), enter amount
4. Dashboard automatically updates totals and pending amounts

---

## Security

| Measure | Implementation |
|---------|---------------|
| APK Obfuscation | Flutter `--obfuscate` flag. Class, function, and variable names are scrambled. Reverse engineering produces meaningless code. |
| No Network | Zero internet calls. All data stays on device. |
| No Cloud | No server, no API, no third-party services. |
| No Secrets | No hardcoded tokens, passwords, or keys. Verified. |

---

## Build

### Local Build

Requirements: Flutter SDK 3.x, Android SDK, Java 17.

```bash
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --obfuscate --split-debug-info=debug-info
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

### Automated Build

Every push to `main` branch triggers GitHub Actions. APK is published as a release.

Latest: [github.com/krsnaSuraj/BillMed/releases/latest](https://github.com/krsnaSuraj/BillMed/releases/latest)

---

## Project Structure

```
BillMed/
├── lib/
│   ├── main.dart                    # App entry + navigation
│   ├── database/
│   │   ├── tables.dart              # SQLite table definitions
│   │   ├── database.dart            # CRUD operations
│   │   └── daos.dart                # Dashboard logic
│   ├── models/enums.dart            # Payment mode enum
│   ├── providers/
│   │   ├── database_provider.dart   # DB state
│   │   └── theme_provider.dart      # Light/dark theme
│   ├── services/
│   │   ├── update_service.dart      # Auto-update checker
│   │   └── export_service.dart      # CSV export
│   ├── screens/
│   │   ├── dashboard/               # Home screen
│   │   ├── bills/                   # List, add, detail
│   │   ├── distributors/            # List, add, detail
│   │   ├── payments/                # Add payment form
│   │   ├── reports/                 # Summary reports
│   │   └── settings/                # Dark mode, export
│   ├── widgets/                     # Status badge, etc.
│   └── theme/                       # Light + dark theme
├── android/                         # Android + Auto Backup
├── .github/workflows/build.yml      # GitHub Actions
├── UPDATE.bat                       # One-click push & build
└── pubspec.yaml                     # Dependencies
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.41 (Dart) |
| Database | Drift (SQLite ORM) |
| State Management | Riverpod |
| CI/CD | GitHub Actions |
| Obfuscation | Flutter --obfuscate |
| Backup | Android Auto Backup |
| Min Android | 6.0 (API 23) |

---

## Version History

| Version | What's New |
|---------|------------|
| `v2.1.2` | README redesign, repo cleanup, bug fixes |
| `v2.1.1` | Bug fixes: status filter, analyze errors cleanup |
| `v2.1.0` | CSV export, reports screen, dashboard navigation fix |
| `v2.0.0` | UI redesign, dark mode, search, 4-tab navigation, new logo |
| `v1.1.1` | APK obfuscation, build script improvements |
| `v1.1.0` | Auto-update service, GitHub Actions CI, new dependencies |
| `v1.0.0` | Initial: distributer/bill/payment tracking |

---

## License

MIT
