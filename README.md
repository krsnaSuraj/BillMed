# 💊 BillMed — Medical Shop Billing & Finance Manager

> A professional Flutter app for medical shop owners to manage suppliers, bills, payments, bank statements, and generate CA-ready financial reports.

---

## ✨ Features

### 📋 Supplier & Bill Management
- Add unlimited suppliers (distributors)
- Create bills with amount, date, and bill number
- Record partial/full payments per bill
- Auto-calculated **Paid / Partial / Unpaid** status with real-time sync
- Search and filter bills by status and supplier

### 💳 Payment Tracking
- Record multiple payments per bill
- Running balance per supplier
- Overdue bill detection (30+ days unpaid)

### 🏦 Bank Statement Import
- Import PDF bank statements from **13+ major Indian banks**:
  `Canara · SBI · HDFC · ICICI · PNB · Axis · Kotak · BOB · Union · Yes · IndusInd · Federal · IDFC`
- Auto-detects bank format — no manual configuration needed
- Optional **Gemini AI** key for best accuracy on complex formats
- Preview & edit transactions before saving
- Balance verification with clear mismatch warnings

### 📊 CA-Ready Reports (FY-Filtered)
- Financial Year filter (April–March, auto-detected)
- **P&L Summary** — Purchase turnover, outstanding payable, payment rate, GST estimate
- **Monthly Bank Breakdown** — Credit/Debit/Net per month
- **Supplier-wise Purchase Table** — Bill date, amount, paid, status
- **Bank Transaction Details** — Full ledger with date, description, debit, credit, balance
- Export as **PDF** (CA-ready) or **CSV**

### 🔄 Backup & Restore
- Manual backup — exports `.db` file, share to Google Drive / WhatsApp / Email
- Restore from `.db` file — full data recovery
- WAL checkpoint before backup for data integrity

### 📱 Transfer to New Phone
- Built-in step-by-step guide in Settings
- Backup → Save → Install → Restore workflow
- Works via Google Drive, WhatsApp, or USB

### 🎨 UI / UX
- Dark mode & Light mode support
- Real-time data sync (stream-based providers)
- Pull-to-refresh on all screens
- Responsive layouts

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| Database | Drift (SQLite) |
| State Management | Riverpod (StreamProvider) |
| PDF Generation | `pdf` package |
| File Sharing | `share_plus` |
| AI Parsing | Google Gemini API |
| Exports | CSV + PDF |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0
- Android SDK / Xcode (for iOS)

### Run locally
```bash
git clone https://github.com/krsnasuraj/BillMed
cd BillMed
flutter pub get
flutter run
```

### Build APK
```bash
flutter build apk --release
```

### UPDATE.bat — Build & Push Script (Windows)
Included in the project root. Double-click to run.

```
Options:
  1. Push + MINOR bump (2.4.X)   → new features/fixes, triggers GitHub APK build
  2. Push + MAJOR bump (X.0.0)   → big releases, triggers GitHub APK build
  3. Push + BUILD bump (x.x.X+1) → same release, NO new APK (just code push)
  4. Local build ONLY             → builds APK for sharing/install
  5. Local build + USB install    → builds and installs on phone via USB
  6. Cancel
```

**When to use which:**
| Option | Use Case |
|--------|----------|
| 1 | Bug fixes, new features — need new APK on GitHub |
| 2 | Major app overhaul — reset minor version |
| 3 | Quick code backup, doc updates — no APK needed |
| 4 | Build APK for WhatsApp/USB sharing |
| 5 | Build + direct install on phone via USB cable |

---

## 📱 Transfer Data to New Phone

1. **Old Phone** → Settings → Manual Backup → Share the `.db` file
2. Save to Google Drive / WhatsApp / Email
3. Install BillMed on new phone
4. **New Phone** → Settings → Restore from Backup → Select `.db` file
5. Restart app — all data restored ✅

---

## 🏦 Bank Statement Import Guide

1. Download your bank statement PDF from NetBanking or your bank's app
2. Open BillMed → Bank Statement → Import PDF
3. App auto-detects your bank and parses transactions
4. Review transactions, fix any errors
5. Save — transactions are stored and linked to your CA report

> 💡 **Tip:** Add a free Gemini API key in Settings for best accuracy.  
> Get key: [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

---

## 📄 CA Report Sections

| Section | Description |
|---------|-------------|
| 1. Purchase & Payables | Total purchases, paid, outstanding, payment rate |
| 2. Bank Cash Flow | Total credits, debits, net, closing balance |
| 3. GST Estimate | Approx. 5% input tax estimate (verify with CA) |
| 4. Monthly Breakdown | Month-wise credit/debit table |
| 5. Supplier-wise Purchase | Bill-by-bill table with paid/due status |
| 6. Transaction Details | Full bank ledger |

---

## 🔐 Security & Privacy

- All data stored **locally on device** (SQLite)
- No cloud sync — your data never leaves your phone
- Backup files are encrypted SQLite databases
- Gemini API (optional) — only the PDF content is sent, not stored

---

## 📦 Version History

| Version | Key Changes |
|---------|-------------|
| v2.5.2 | Batch insert + duplicate detection — crash fix for large imports |
| v2.5.1 | NotoSans font fix, CA export options dialog, zero lint |
| v2.5.0 | Multi-bank parser, CA report overhaul, phone transfer guide |
| v2.4.1 | Fresh build with all pending updates |
| v2.4.0 | Removed 'payment' from debit keywords (UPI/CR false positive fix) |
| v2.3.9 | Gemini error no longer blocks local parser + byte-level stream search |
| v2.3.8 | 'paid' keyword removed from debit detection |
| v2.3.7 | PDF extraction overhaul: BT/ET block parsing, ' operator |
| v2.3.6 | Final cleanup: unused imports removed, zero analyzer issues |
| v2.3.5 | Opening/closing balance multi-line detection fix |
| v2.3.4 | CA Report PDF: full transaction table with opening/closing balance |
| v2.3.3 | Canara bank statement fix: line merging, UPI/CR keyword fix |
| v2.3.2 | Bank parser: integer amounts, credit detection |
| v2.3.1 | Release build — CI/CD release fix |
| v2.3.0 | Gemini AI integration, bank transactions view, CA report PDF |
| v2.2.2 | Bug fixes: backup crash, notification fix |
| v2.2.0 | Bank statement import with golden rule verification |
| v2.1.0 | CSV export, reports, dark mode |
| v2.0.0 | Complete UI redesign |
| v1.0.0 | Initial release |

Current version: `pubspec.yaml` — use `UPDATE.bat` to bump and push.

---

## 🤝 Contributing

Pull requests welcome. Open an issue for bugs or feature requests.

---

*Made with ❤️ for Indian medical shop owners*
