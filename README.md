<div align="center">
  <h1>BillMed</h1>
  <p><strong>Distributor Bill Payment Tracker for Medical Retail Shops</strong></p>
  <p>Offline · Local · Private</p>
</div>

---

## 📌 What is this?

BillMed helps medical shop owners track purchase bills from distributors and wholesalers. Record incoming bills, mark payments against them (Cash/UPI/Cheque/NEFT/RTGS), and always know exactly how much is pending with which supplier.

This is NOT a cloud app. All data stays on the device. No internet required.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Supplier Management** | Add distributors with name, company, phone |
| **Bill Tracking** | Record bills with number, date, amount |
| **Payment Tracking** | Mark payments with mode (Cash/UPI/Cheque/NEFT/RTGS) |
| **Auto Status** | Bills auto-tag as Unpaid / Partial / Paid |
| **Dashboard** | Real-time summary of billed, paid, pending amounts |
| **Dark Mode** | Toggle between light and dark themes |
| **Search & Filter** | Search bills by number/supplier, filter by status |
| **CSV Export** | Export all data as CSV — share via WhatsApp/email |
| **Auto Backup** | Android Auto Backup syncs data to Google Drive |
| **Auto Updates** | App checks for new versions and prompts update |
| **100% Offline** | No internet required. Data never leaves your device |

---

## 📱 App Preview

```
┌─────────────────────────────────────────┐
│              BillMed                     │
├─────────────────────────────────────────┤
│  ┌──────────┐  ┌────────┐               │
│  │₹1,50,000 │  │₹1,20K  │               │
│  │Total     │  │Paid    │               │
│  │Billed    │  └────────┘               │
│  └──────────┘  ┌────────┐               │
│                │₹30,000 │               │
│                │Pending │               │
│                └────────┘               │
│                                          │
│  Sterling Pharma           ₹12,000       │
│  Alkem Labs                 ₹8,000       │
│  Cipla                     ₹10,000       │
│                                          │
│  [🏠 Dash]  [🧾 Bills]  [🏢 Suppliers] │
│  [⚙️ Settings]                          │
└─────────────────────────────────────────┘
```

---

## 🛡️ Security

| Measure | Implementation |
|---------|---------------|
| **APK Obfuscation** | Flutter `--obfuscate` flag — all code symbols renamed |
| **No Network** | Zero internet calls. Data stays on device |
| **No Cloud** | No server, no API, no third-party services |
| **Private Repo** | Source code only accessible to authorized users |
| **No Secrets** | No hardcoded tokens, passwords, or keys |

The APK is built with full obfuscation. Class names, function names, and variable names are scrambled. Reverse engineering produces meaningless code.

---

## 🔧 Build

### Local Build

```bash
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --obfuscate --split-debug-info=debug-info
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

### GitHub Actions (Auto Build)

Every push to `main` branch triggers an automatic build.  
Latest APK: [Releases](https://github.com/krsnaSuraj/BillMed/releases/latest)

---

## 📁 Project Structure

```
BillMed/
├── lib/
│   ├── main.dart                          # App entry + navigation
│   ├── database/
│   │   ├── tables.dart                    # SQLite table definitions
│   │   ├── database.dart                  # CRUD operations
│   │   └── daos.dart                      # Dashboard logic
│   ├── models/enums.dart                  # Payment mode enum
│   ├── providers/
│   │   ├── database_provider.dart         # DB state
│   │   └── theme_provider.dart            # Theme state
│   ├── services/
│   │   ├── update_service.dart            # Auto-update checker
│   │   └── export_service.dart            # CSV export
│   ├── screens/
│   │   ├── dashboard/                     # Home screen
│   │   ├── bills/                         # List, add, detail
│   │   ├── distributors/                  # List, add, detail
│   │   ├── payments/                      # Add payment
│   │   ├── reports/                       # Reports
│   │   └── settings/                      # Dark mode, export
│   ├── widgets/                           # Reusable components
│   └── theme/                             # Light + dark themes
├── android/                               # Android config + backup
├── .github/workflows/build.yml            # GitHub Actions CI
├── UPDATE.bat                             # One-click push & build
└── pubspec.yaml                           # Dependencies
```

---

## 🗄️ Database Schema

```
distributors → bills → payments
```

**distributors**: id, name, company, phone, created_at  
**bills**: id, distributor_id, bill_number, bill_date, amount, notes, created_at  
**payments**: id, bill_id, payment_date, amount, mode (Cash|UPI|Cheque|NEFT|RTGS), reference_no, notes, created_at  

Bill status is computed on-the-fly: compare `SUM(payments.amount)` with `bills.amount`.

---

## 🧰 Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.41 (Dart) |
| Database | Drift (SQLite ORM) |
| State | Riverpod |
| Build | GitHub Actions |
| Obfuscation | Flutter `--obfuscate` |
| Backup | Android Auto Backup |
| Min SDK | Android 6.0 |

---

## 📊 Version History

| Version | Description |
|---------|-------------|
| `v2.1.1` | Bug fixes: status filter, analyze cleanup |
| `v2.1.0` | CSV export, reports screen, dashboard fix |
| `v2.0.0` | UI redesign, dark mode, search, 4-tab nav, logo |
| `v1.1.1` | APK obfuscation, build script fixes |
| `v1.1.0` | Auto-update service, GitHub Actions CI |
| `v1.0.0` | Initial release |

---

<div align="center">
  <p>Built with Flutter · Drift · Riverpod</p>
</div>
