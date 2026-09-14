# Changelog

All notable changes to BillMed. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions match
`pubspec.yaml` (`version: <name>+<build>`) — the same string the app shows in
Settings and the same one the in-app update check compares against the GitHub
release tag.

## 0.1.1+7

The release that makes the supplier page tell the whole truth, and that closes
the ways a bad file or a bad number could have cost money.

### Fixed

- **The supplier page never showed the bill list.** The Billed / Paid / Pending
  strip was a stretched `Row` sitting directly in a sliver box, which offers an
  unbounded height: its stretched children demanded an infinite height, the
  tiles painted, and everything below them — the entire bill ledger — was pushed
  out of the layout. The strip is now wrapped in `IntrinsicHeight`, so the tiles
  keep one shared height and the ledger renders. Pinned by a regression test that
  asserts the tile height is finite and the ledger below it is laid out.
- **The Pay Full chip looked pre-ticked.** It drew a tick before any tap, claiming
  the full amount was filled while the field was still empty. The chip now
  reports state: bolt + `Pay Full` while the amount is empty or partial, tick +
  `Full amount` only when the field really holds the whole outstanding balance
  (typed by hand or filled by the shortcut). Tapping the ticked chip takes the
  fill back, and `InputChip` can no longer draw its own checkmark.
- **Long supplier names were cut off.** The name column was ~138 dp wide, next to
  the dues amount, so a trade name like "Shree Ganesh Medical Agency (Wholesale)"
  ended in an ellipsis. The name now owns the full width of its column (the dues
  amount moved to the meta line), wraps at word boundaries, and — when even that
  cannot hold it — scrolls its own line instead of being cut. Hidden tabs also
  stop animating (`TickerMode`), so a scrolling name cannot burn battery in the
  background.
- **The dashboard headline could contradict the rows under it.** Pending was
  computed as `Σ billed − Σ paid` across all suppliers, so one supplier's advance
  cancelled another supplier's debt: the headline read `₹0 pending` directly above
  a red `₹50 due` row, and the Suppliers tab said `₹0 dues` over an unpaid
  supplier. The headline is now the sum of the per-supplier dues — always equal to
  the rows on screen.
- **`12,50` was silently read as ₹1,250.** Commas were stripped blindly from the
  amount fields, so a decimal comma meant a hundred-fold entry error that nothing
  echoed back. Commas are now honoured only as digit grouping (Indian and Western
  shapes); anything else makes the input invalid and the form says so.
- **A supplier that had only *netted* its dues away was shown as `Clear`.** With an
  advance on one bill and an unpaid bill on another, the net is zero but money is
  still owed. `Clear` (tile, row tint and rail colour) now requires every bill
  settled **and** no net dues.
- **The Paid tile did not add up to the Paid list.** The tile showed every payment
  while the `Paid` scope showed only settled bills, so a supplier with one ₹1,000
  bill holding a ₹400 payment showed `Paid ₹400` beside a `Paid (0)` chip. The
  scope now means "bills with money on them", which is exactly the set whose
  `Paid` lines sum to the tile.
- **Editing a bill's date could lock an existing payment forever.** A payment
  dated before its bill was refused on save, including when editing that already
  stranded payment. The rule now applies to creation only, so the user is never
  trapped with a row they cannot edit.
- **Deleted-payment Undo silently did nothing once the screen was gone.** The
  snackbar callback read the Riverpod `ref` after the route had been disposed,
  threw, and the error was swallowed. The database handle is captured before the
  snackbar is shown.
- **The Bills tab could stay pinned to a deleted supplier.** The list went empty
  behind a pill that fell back to its generic label. A stale supplier filter is
  now dropped automatically.
- **Legacy ₹0 bills never settled.** They showed `Due ₹0` and counted as overdue
  forever. A zero-amount bill now settles.
- **`AnimatedMoney` accumulated a listener per value change**, running one extra
  `setState` per frame for every update. It now keeps a single tick listener.
- **The dashboard read the clock twice** (`monthlyPurchasePaise` and
  `lastSixMonths`), so the bars and the month labels could disagree across a month
  boundary. One read feeds both.

### Added

- **Bill-wise detail on the supplier page.** Every bill now shows its own
  `Billed`, `Paid` and `Due` line — `Advance` when overpaid, an `Overdue` suffix
  past the 30-day rule — ordered newest first.
- **Supplier bill scopes**: All / Pending / Paid / Overdue chips with live counts,
  where the Billed, Paid and Pending tiles *are* the filters for the bills behind
  those numbers. The active tile stays visibly pressed down, the header count
  follows the filter, and a filtered-to-nothing ledger names its own scope and
  offers `Show all bills` instead of claiming the supplier has no bills.
- `lib/services/bill_view_service.dart` — the scopes, counts and ordering as a
  pure, unit-tested module.
- `WrapOrScrollText` — the widget that guarantees a name is never ellipsised.
- **The pre-restore safety copy is now visible and re-shareable** in My Backups
  (manual → before-restore → auto), and My Backups validates the file with the
  same gate the restore uses before sharing it.

### Security

- **A crafted "legacy" backup could brick the app permanently.** The restore probe
  only required an `amount` column for schema v1–v3 files, then copied the file
  over the ledger; on the next launch drift's migration failed on the missing
  columns, `user_version` stayed old, and every later open threw — and because the
  pre-restore safety copy needs a working database, the in-app way back was gone
  too. The gate now validates the **complete column set** for the file's declared
  version (the same set the migration reads), so such a file is refused before it
  can touch anything.
- The restore gate also now rejects negative or absurd money values (rows beyond
  ₹100 crore per row, which could overflow SQLite's `SUM()`), in addition to the
  existing header, size, version, table, trigger/view and `integrity_check`
  checks.
- **Backups are verified before they are published.** A snapshot is only renamed
  into place after it opens, validates, and holds exactly the same row counts as
  the live ledger; the byte-copy fallback now requires a successful WAL
  checkpoint, so a silently stale backup can no longer be reported as saved.
- The update check no longer renders unbounded network text: the release tag must
  match a strict version-shaped pattern (≤ 24 characters) and the response is
  size-capped before decoding.
- The recovery advice and disclosure moved to where the user acts: the Backup Now
  tile states that the file is not encrypted, the share text repeats it, and the
  restore confirmation says to only restore files BillMed itself created.

### Removed

- **The supplier PDF statement export** (Share Statement) and the `pdf`
  dependency it needed (10 transitive packages). The supplier page answers the
  same question faster, and the export was not used.
- Dead code and cruft: an unread `isLast` field, a `BackupService.isBusy` getter
  that could never be true at its call site, an always-true migration guard, an
  unreachable sparkline guard, a dead null branch, two duplicated comparison
  helpers, three unused bundled assets (432 KB of APK payload), the stale
  `BillMed-v0.1.0.apk`, and session logs.

### Internal

- Version `0.1.1` (build `7`).
- Test suite grew substantially, adding files for payment guards, the restore
  gate, bill/ledger operations, dashboard money, the supplier-add form, update-tag
  validation and long names, plus a shared harness.
- `flutter analyze --fatal-infos` and `dart format --set-exit-if-changed lib`
  are clean; CI runs both plus the full suite on every push.

## 0.1.0+5

Initial release: offline supplier khata — suppliers, bills, part and full
payments, dashboard with dues and a six-month sparkline, bill and supplier detail
pages, PDF supplier statement, backup / restore, light–dark–system theme, and a
manual update check.
