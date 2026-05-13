# BillMed

> Distributor bill payment tracker for medical retail shops.

BillMed helps shopkeepers track purchase bills from distributors and wholesalers. Record incoming bills, mark payments, and always know exactly how much is pending with which supplier.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Distributor Management** | Add and manage suppliers with name, company, and phone |
| **Bill Tracking** | Record purchase bills with number, date, and amount |
| **Payment Tracking** | Mark payments against specific bills |
| **Payment Modes** | Cash · UPI · Cheque · NEFT · RTGS |
| **Auto Status** | Bills auto-tag as Unpaid / Partial / Paid |
| **Dashboard** | See pending amounts per distributor at a glance |
| **Auto Backup** | Android Auto Backup syncs data to Google Drive |
| **In-App Updates** | App checks for new versions and prompts update |
| **Dark Mode** | Toggle between light and dark themes |
| **Search & Filter** | Search bills and filter by status |
| **Large Fonts** | Elderly-friendly UI with big text and buttons |
| **100% Offline** | No internet required. Data stays on device. |

---

## 📸 App Preview

```
┌─────────────────────────────────────┐
│            BillMed                  │
├─────────────────────────────────────┤
│  Total Billed   Total Paid  Pending │
│    ₹50,000       ₹35,000   ₹15,000 │
│                                     │
│  Distributors Summary               │
│  ┌─────────────────────────────┐   │
│  │ S  Sterling Pharma          │   │
│  │    Alkem Labs     ₹10,000  │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ C  Cipla                    │   │
│  │              ₹0   ✅ Paid  │   │
│  └─────────────────────────────┘   │
│                                     │
│  [🏠 Home]    [📋 Distributors]   │
└─────────────────────────────────────┘
```

---

## 🚀 How It Works

### For the Shop Owner

**Three simple actions:**

1. **Add a distributor** — one-time setup (name, company)
2. **Add a bill** — when goods arrive, enter bill number + amount
3. **Add a payment** — when you pay, select the bill and mode (Cash/UPI/Cheque)

The dashboard automatically calculates totals and pending amounts.

### For the Developer (You)

**Update flow when making changes:**

```
1. Edit code in lib/ directory
2. Run UPDATE.bat
   → Version bumps automatically
   → Code pushes to GitHub
   → GitHub Actions builds new APK
3. User opens app → sees update popup
4. Taps "Update" → APK downloads → installs
```

---

## 🔧 Build Instructions

### Local Build

```bash
# Prerequisites: Flutter SDK 3.x
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --obfuscate --split-debug-info=debug-info
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

### Automated Build (GitHub Actions)

Every push to `main` branch triggers an automatic build on GitHub Actions.  
The APK is published as a GitHub Release.

Latest release: [github.com/krsnaSuraj/BillMed/releases/latest](https://github.com/krsnaSuraj/BillMed/releases/latest)

---

## 📁 Project Structure

```
BillMed/
├── lib/
│   ├── main.dart                          # App entry + update check
│   ├── database/
│   │   ├── tables.dart                    # SQLite table definitions
│   │   ├── database.dart                  # CRUD operations
│   │   └── daos.dart                      # Dashboard business logic
│   ├── models/enums.dart                  # Payment mode enum
│   ├── providers/database_provider.dart   # State management
│   ├── services/update_service.dart       # In-app update checker
│   ├── screens/
│   │   ├── dashboard/                     # Home screen
│   │   ├── distributors/                  # Distributor list, add, detail
│   │   ├── bills/                         # Bill add, detail
│   │   └── payments/                      # Payment entry
│   ├── widgets/                           # Reusable UI components
│   └── theme/                             # App theme (large fonts)
├── android/                               # Android config + Auto Backup
├── .github/workflows/build.yml            # GitHub Actions CI
├── UPDATE.bat                             # One-click build & push
└── pubspec.yaml                           # Flutter dependencies
```

---

## 🛡️ Security

| Measure | Status |
|---------|--------|
| APK code obfuscation | Enabled (Flutter `--obfuscate`) |
| Data encryption | Device-level (Android Auto Backup) |
| Network | No network calls (fully offline) |
| Hardcoded secrets | None (verified) |

---

## 🗄️ Database Schema

```
distributors
  ├── id (INTEGER PK)
  ├── name (TEXT)
  ├── company (TEXT NULL)
  ├── phone (TEXT NULL)
  └── created_at (DATETIME)

bills
  ├── id (INTEGER PK)
  ├── distributor_id → FK → distributors.id
  ├── bill_number (TEXT)
  ├── bill_date (DATETIME)
  ├── amount (REAL)
  ├── notes (TEXT NULL)
  └── created_at (DATETIME)

payments
  ├── id (INTEGER PK)
  ├── bill_id → FK → bills.id
  ├── payment_date (DATETIME)
  ├── amount (REAL)
  ├── mode (TEXT)          — Cash/UPI/Cheque/NEFT/RTGS
  ├── reference_no (TEXT NULL)
  ├── notes (TEXT NULL)
  └── created_at (DATETIME)
```

---

## 🧰 Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.41 (Dart) |
| Database | Drift (SQLite ORM) |
| State Management | Riverpod |
| Updates | GitHub Actions + in-app checker |
| Obfuscation | Flutter `--obfuscate` |
| Backup | Android Auto Backup (Google Drive) |
| Min Android | 6.0 (API 23) |

---

## 🎨 Color Scheme

| Role | Color | Hex |
|------|-------|-----|
| Primary | Deep Indigo | `#1A237E` |
| Accent | Teal | `#00BFA5` |
| Background | Light Grey | `#F5F7FA` |
| Dark BG | Dark Navy | `#0F0F23` |

---

## 📊 Version History

| Commit | Description |
|--------|-------------|
| `v2.0.0` | Complete UI redesign, dark mode, search & filter, new logo, 4-tab navigation |
| `v1.1.1` | APK obfuscation, updated README, build script fixes |
| `v1.1.0` | Auto-update service, GitHub Actions CI, new deps |
| `v1.0.0` | Initial release with distributor/bill/payment tracking |
