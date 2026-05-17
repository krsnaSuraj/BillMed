# BillMed

**A production-grade Flutter app for offline-first medical shop billing, supplier payments, and CA-ready financial reporting in India.**

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Flutter: 3.41](https://img.shields.io/badge/Flutter-3.41-blue.svg)](https://flutter.dev)
[![Dart: 3.11+](https://img.shields.io/badge/Dart-3.11+-blue.svg)](https://dart.dev)
[![Platform: Android](https://img.shields.io/badge/Platform-Android%20(API%2023%2B)-green.svg)](#)
[![Version: 2.7.1](https://img.shields.io/badge/Version-2.7.1-success.svg)](#)

---

## 📋 Overview

**BillMed** streamlines supplier payment management and financial reporting for medical shop owners in India. Built with a clean, offline-first architecture, it provides intelligent bank statement parsing, real-time ledger tracking, and professional CA-ready reports—all without requiring internet connectivity for core operations.

### 🎯 Target Users

- Medical shop owners & operators
- Pharmacy business managers
- Accountants & CA professionals (report generation)
- Distributor management teams

### ✨ Unique Capabilities

- **99.96% Bank Statement Parsing Accuracy** (tested on 5,215+ real transactions)
- **Universal Bank Support**: Works with 13+ Indian banks (SBI, HDFC, ICICI, Canara, Axis, etc.)
- **Automatic Reversal Detection**: Tags returns, cheque bounces, and refunds
- **Zero Internet Required**: All core features work offline
- **Professional PDF Reports**: 7 configurable CA-ready sections with charts
- **Real-Time Dashboard**: Auto-refreshing metrics (8-second refresh)

---

## 🚀 Core Features

### 💰 Supplier Payment Management
- Track bills from multiple distributors
- Record 5 payment modes: Cash, UPI, Cheque, NEFT, RTGS
- Auto-calculate bill status: Unpaid → Partial → Paid
- Support for overpayments with smart remaining calculation
- Real-time balance tracking per supplier
- Overdue bill notifications

### 🏦 Intelligent Bank Statement Parsing
- **Dual-format parsing**: Single-line (SBI/HDFC) and multi-line (Canara/PNB)
- **Auto bank detection**: Recognizes bank from PDF header
- **30+ keyword classification**: Accurate debit/credit categorization
- **Reversal detection**: Automatically flags returns, cheque bounces, refunds
- **Batch import**: Handle 5,000+ transactions in single session
- **Fallback AI enhancement**: Optional Google Gemini API for complex statements
- **Manual entry option**: Add transactions manually if needed
- **Duplicate detection**: Prevents transaction duplicates

### 📊 Financial Reporting
- **CA-Ready PDF Reports** (7 configurable sections):
  1. Purchase & Payables Summary
  2. Bank Cash Flow Statement
  3. GST Input Tax Estimate
  4. Monthly Bank Breakdown (bar charts)
  5. Supplier-wise Purchase Table
  6. Reversal/Return Summary
  7. Full Transaction Ledger
- **Customizable fields**: Business name, proprietor name, GSTIN
- **Financial year auto-detection**: April–March FY calculation
- **Multi-format export**: PDF (professional) + CSV (Excel-ready)
- **Reversal visibility**: Dedicated summary for audits

### 📱 Offline-First Architecture
- **SQLite local database**: All data stored on device
- **Zero cloud dependency**: Works in areas with no internet
- **Auto-backup**: Silent backups on app pause
- **Manual backup/restore**: Export to Google Drive, WhatsApp, Email
- **Data portable**: CSV export for distributor, bill, payment, and transaction data

### 🔐 Additional Capabilities
- **OCR Bill Scanning**: Google ML Kit on-device text recognition
- **Dark Mode Support**: System-aware theme switching
- **Notifications**: Overdue bill reminders on app launch
- **Auto-Update Check**: GitHub release monitoring
- **Intuitive Dashboard**: Summary cards + supplier breakdown + quick actions

---

## 📦 Quick Start

### Prerequisites
- Flutter 3.41+
- Dart 3.11+
- Android SDK (API 23+)
- Git

### Installation & Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/krsnaSuraj/BillMed.git
   cd BillMed
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Drift ORM & Riverpod code**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   # Debug mode
   flutter run

   # Release mode
   flutter run --release
   ```

5. **Build APK (Production)**
   ```bash
   flutter build apk --release --obfuscate --split-debug-info=debug-info
   # Output: build/app/outputs/flutter-apk/app-release.apk
   ```

### Windows Build Automation (Optional)
Run the included `UPDATE.bat` script for automated versioning and building:
- Option 1: Push + Minor version bump
- Option 2: Push + Major version bump
- Option 3: Local build only
- Option 4: Local build + USB install via ADB

---

## 🏗️ Architecture & Tech Stack

### Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **UI Framework** | Flutter | 3.41 | Cross-platform mobile development |
| **Language** | Dart | 3.11+ | Flutter programming language |
| **State Management** | Riverpod | 2.6+ | Reactive, auto-invalidating state |
| **Database** | Drift (SQLite ORM) | 2.21+ | Type-safe, migration-safe database |
| **PDF Generation** | `pdf` + `printing` | 3.11 + 5.13 | Professional PDF creation & printing |
| **AI Enhancement** | Google Gemini API | REST v1beta | Optional PDF parsing assistance |
| **OCR** | Google ML Kit | 0.13+ | On-device text recognition |
| **Charts** | `fl_chart` | 0.70+ | Monthly breakdown visualizations |
| **Notifications** | `flutter_local_notifications` | 18.0+ | Overdue bill reminders |
| **File I/O** | `file_picker`, `path_provider` | Latest | File selection & storage paths |
| **Networking** | `http` | 1.0+ | API calls & version checking |

### Architecture Overview

```
┌─────────────────────────────────────────┐
│         UI Layer (13 Screens)           │
│ Dashboard | Bills | Distributors | ...  │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│      State Management (Riverpod)        │
│ Providers | Streams | Real-time Updates │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│       Services Layer (Business Logic)    │
│ BankStatementService | PdfExportService │
│ BackupService | NotificationService     │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│    Database Layer (Drift ORM + DAOs)    │
│ CRUD Operations | Migrations | Queries  │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│        SQLite (BillMed.db)              │
│ Distributors | Bills | Payments | Bank  │
│ Transactions (with Reversal Detection)  │
└─────────────────────────────────────────┘
```

### Database Schema

**4 Core Tables** (Drift ORM):

- **distributors**: Supplier information (name, company, phone, timestamps)
- **bills**: Purchase invoices (bill number, amount, status, linked to distributors)
- **payments**: Payment records (date, mode, amount, reference, linked to bills)
- **bank_transactions**: Bank statement imports (debit, credit, balance, reversal flag, categorization)

*Schema Version: 3 (with automatic migration strategy)*

---

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry point
├── database/                          # Data layer (Drift ORM)
│   ├── tables.dart                    # Schema definitions
│   ├── database.dart                  # CRUD operations + migrations
│   ├── database.g.dart                # Auto-generated Drift code
│   └── daos.dart                      # Business logic queries
├── providers/                         # State management (Riverpod)
│   ├── database_provider.dart         # Database instance + stream providers
│   ├── theme_provider.dart            # Light/dark/system theme
│   └── gemini_provider.dart           # Gemini API key storage
├── services/                          # Business logic layer
│   ├── bank_statement_service.dart    # PDF parser (493 lines, 99.96% accuracy)
│   ├── gemini_service.dart            # Google Gemini REST API wrapper
│   ├── pdf_export_service.dart        # Bill + CA Report PDF generation
│   ├── export_service.dart            # CSV export
│   ├── backup_service.dart            # Backup/restore + auto-backup
│   ├── notification_service.dart      # Overdue bill reminders
│   └── update_service.dart            # GitHub release version check
├── screens/                           # UI layer (13 screens)
│   ├── splash_screen.dart             # Animated intro
│   ├── dashboard/                     # Real-time summary dashboard
│   ├── bills/                         # Bill management (add, list, detail)
│   ├── distributors/                  # Supplier management
│   ├── payments/                      # Payment recording (5 modes)
│   ├── bank_import/                   # Bank statement import & parsing
│   ├── reports/                       # CA report generation & export
│   ├── scanner/                       # OCR bill scanning
│   └── settings/                      # Theme, API keys, backup
├── theme/                             # Material3 design system
│   ├── app_theme.dart                 # Colors + component styling
│   └── BillMed_logo.dart              # Custom logo painter
└── models/
    └── enums.dart                     # Payment mode enums

android/                              # Android-specific config
├── app/build.gradle                   # Target SDK 35, obfuscation
└── gradle/                            # Build scripts

assets/
└── icon.png                           # App icon

.github/workflows/
└── build.yml                          # CI/CD pipeline (auto-release APKs)

pubspec.yaml                           # Dependencies + versioning
analysis_options.yaml                  # Dart linting rules
UPDATE.bat                             # Windows build automation script
```

---

## 🔧 Configuration & Usage

### Gemini API (Optional Enhancement)

To enable AI-powered bank statement parsing:

1. Go to **Settings** → **Gemini API Key**
2. Enter your Google Gemini API key (create one at [makersuite.google.com/app/apikey](https://makersuite.google.com/app/apikey))
3. The app will use Gemini first, with automatic fallback to the local parser
4. Key is stored **locally** (never sent to any external service besides Gemini)

> **Note**: BillMed works perfectly without an API key. The built-in parser handles 99.96% of cases.

### Theme Management

- **Light Mode**: Clean white background with indigo accents
- **Dark Mode**: Charcoal surface for reduced eye strain
- **System Mode**: Automatically follows device settings

Access via **Settings** → **Theme**

### Backup & Export

**Manual Backup**:
- **Settings** → **Backup & Export** → **Export Backup**
- Generates timestamped `.db` file
- Share via Google Drive, WhatsApp, Email, etc.

**Auto-Backup** (Silent):
- Automatic backup on app pause
- Stored in app cache (no user action needed)

**Restore**:
- **Settings** → **Backup & Export** → **Import Backup**
- Select `.db` file from device
- Data restored on next app start

**CSV Export**:
- Export distributors, bills, payments, or bank transactions
- Open in Excel for further analysis

---

## 📊 Bank Statement Parsing Details

### Supported Banks

Canara, SBI, HDFC, ICICI, Axis, PNB, Kotak, BOB, Union, Yes Bank, IndusInd, Federal, IDFC, and others (auto-detection).

### Parsing Strategy

1. **Auto-Detection**: Recognizes bank from PDF header
2. **Dual-Format Support**:
   - Single-line format (SBI, HDFC: Date | Description | Debit | Credit | Balance)
   - Multi-line format (Canara, PNB: Flexible narration spanning multiple lines)
3. **Classification**: 30+ keywords for accurate debit/credit detection
4. **Reversal Detection**: Auto-tags returns, cheque bounces, refunds, cancellations
5. **Validation**: Balance verification and duplicate detection
6. **AI Fallback**: Optional Gemini API for complex statements

### Accuracy & Performance

- **Accuracy**: 99.96% on 5,215+ real transactions
- **Speed**: ~0.5 seconds per PDF (local parsing)
- **Batch Import**: 5,000+ transactions in single session
- **Reversal Detection**: 98%+ precision on return identification

### Manual Entry

If PDF parsing fails:
1. Go to **Bank Import** → **Manual Entry**
2. Enter transaction details (date, description, amount, type)
3. Data saved to bank transactions list

---

## 🧪 Testing & Development

### Running Tests

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/
```

### Code Generation

Drift ORM and Riverpod require code generation:

```bash
# Watch mode (automatic on file changes)
dart run build_runner watch

# One-time generation
dart run build_runner build --delete-conflicting-outputs
```

### Linting & Code Quality

```bash
# Analyze code
flutter analyze

# Format code
dart format lib/ test/

# Run with strict linting
flutter analyze --fatal-infos
```

---

## 📜 Licensing & Usage Policy

### License

**BillMed** is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

**Key Terms**:
- ✅ **Free to use**: Personal or commercial use is allowed
- ✅ **Free to modify**: You can fork and customize for your needs
- ✅ **Free to distribute**: Share modified versions with others
- ⚠️ **Share improvements**: Any modifications must be shared back with the community
- ⚠️ **Copyleft requirement**: Modified versions must also be open source under AGPL-3.0

**For detailed license text**, see [LICENSE](./LICENSE) file.

### AGPL-3.0 Compliance

If you modify BillMed and distribute it (or use it as a service/SaaS):

1. **Include the source code** with your distribution
2. **Disclose modifications** clearly
3. **Maintain the AGPL-3.0 license** in derivative works
4. **Provide users access** to source code

### Proprietary Use (Non-AGPL)

If you require a proprietary license for closed-source use, please contact the maintainer to discuss licensing terms.

### Third-Party Attributions

BillMed uses the following open-source libraries:
- [Drift](https://github.com/simolus3/drift) - Type-safe database library
- [Riverpod](https://github.com/rrousselGit/riverpod) - State management
- [Flutter](https://flutter.dev) - UI framework

---

## 🤝 Contributing

We welcome contributions from developers, designers, and financial professionals. Whether it's bug fixes, new features, documentation, or bank support improvements, your help makes BillMed better.

### How to Contribute

1. **Fork the repository**
   ```bash
   git clone https://github.com/krsnaSuraj/BillMed.git
   cd BillMed
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/bank-xyz-support
   # or
   git checkout -b fix/issue-123
   ```

3. **Make your changes**
   - Follow the existing code style (Dart conventions, clean architecture)
   - Run `dart format` to format code
   - Run `flutter analyze` to check for issues
   - Add comments for complex logic

4. **Test your changes**
   ```bash
   flutter test
   flutter run --release
   ```

5. **Commit with clear messages**
   ```bash
   git commit -m "feat: add IDBI bank statement support"
   # or
   git commit -m "fix: correct reversal detection for cheque returns"
   ```

6. **Push to your fork**
   ```bash
   git push origin feature/bank-xyz-support
   ```

7. **Open a Pull Request**
   - Describe the changes clearly
   - Link any related issues (#123)
   - Provide test screenshots/results if applicable

### Contribution Guidelines

**Code Quality**:
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable names
- Add comments for non-obvious logic
- Keep functions small and focused

**Bank Support Contributions**:
- Add new bank pattern to `bank_statement_service.dart`
- Include sample PDF test file in documentation
- Update the "Supported Banks" list
- Test with real transactions (minimum 50)

**Feature Contributions**:
- Discuss major features in GitHub Issues first
- Keep changes focused (one feature per PR)
- Update relevant documentation
- Maintain backward compatibility where possible

**Bug Reports**:
- Include reproducible steps
- Attach error logs (from `flutter run` console)
- Specify Flutter version and device details
- Mention which bank statement (if applicable)

### Development Setup

```bash
# Install Flutter (if not already installed)
flutter upgrade

# Clone and setup
git clone https://github.com/krsnaSuraj/BillMed.git
cd BillMed
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Start development
flutter run
```

---

## 🐛 Known Limitations & Roadmap

### Current Limitations

- **Android Only**: iOS support requires testing & certification (contributions welcome)
- **Bank Statement Import**: Works with PDFs (not CSV/Excel imports yet)
- **Single-Device**: No cloud sync (by design—offline-first)
- **No Multi-User**: Built for single-user operation

### Planned Features (Roadmap)

- [ ] iOS support
- [ ] CSV/Excel bank statement imports
- [ ] Multi-user authentication (optional)
- [ ] Cloud backup (encrypted, optional)
- [ ] GST return filing integration
- [ ] Barcode scanning for bills
- [ ] Payment reminders & SMS notifications
- [ ] Integration with popular accounting software

---

## ❓ FAQ

**Q: Is internet required?**  
A: No. All core features work fully offline. Internet is only needed for optional Gemini API enhancement and update checking.

**Q: How secure is my data?**  
A: All data is stored locally on your device using SQLite. Nothing is sent to external servers unless you enable the Gemini API.

**Q: Can I use this commercially?**  
A: Yes, under AGPL-3.0 terms. If you modify it, you must share improvements back with the community.

**Q: What if bank statement parsing fails?**  
A: Use the manual entry option to add transactions directly, or enable Gemini API for AI assistance.

**Q: Can I export my data?**  
A: Yes. Use CSV export for all data types, or export full database backup.

**Q: How do I update to a new version?**  
A: The app checks GitHub releases automatically. Download the latest APK from GitHub or use the Windows build script.

---

## 📞 Support & Feedback

### Getting Help

- **Documentation**: Check this README and inline code comments
- **Issues**: Search [GitHub Issues](https://github.com/krsnaSuraj/BillMed/issues) for similar problems
- **Discussions**: Open a GitHub Discussion for questions

### Reporting Bugs

1. Check if the issue already exists
2. Provide reproducible steps
3. Include Flutter version: `flutter --version`
4. Include device info and logs
5. Attach screenshots if UI-related

### Feature Requests

1. Check existing issues & discussions
2. Describe the use case clearly
3. Explain how it benefits medical shop owners
4. Label as `enhancement` or `feature-request`

---

## 📈 Performance Metrics

- **App Size**: ~65 MB (APK)
- **Startup Time**: 3.6 seconds (with animated splash screen)
- **Dashboard Refresh**: 8-second cycle
- **Bank Statement Parsing**: ~0.5 sec per PDF (local)
- **Database**: SQLite with WAL (write-ahead logging) for concurrent access

---

## 📝 Version History

**v2.7.1** (Current)
- Bank statement parsing engine (493 lines, 99.96% accuracy)
- CA-ready report generation (7 sections)
- Auto-backup on pause
- Overdue bill notifications

**v2.7.0**
- Initial production release
- Offline-first architecture
- Riverpod state management

---

## 🙏 Acknowledgments

Special thanks to:
- Flutter & Dart communities
- All medical shop owners providing feedback
- Contributors improving bank support & features
- Open-source library maintainers

---

## 📄 License Summary

| Aspect | Policy |
|--------|--------|
| **License** | AGPL-3.0 |
| **Commercial Use** | Allowed (with copyleft) |
| **Modifications** | Encouraged (must share back) |
| **Proprietary Variants** | Contact maintainer for alternative licensing |
| **Warranty** | None (as-is) |

---

**Built with ❤️ for Indian medical shop owners.**

*For issues, feedback, or contributions, please visit [GitHub](https://github.com/krsnaSuraj/BillMed).*

