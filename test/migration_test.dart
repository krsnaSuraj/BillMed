// REAL v3 → v4 migration test with a temp-file DB.
//
// PATH TAKEN (documented per task): file-based migration via a minimal drift
// probe database (_RawV3Db below), NOT `package:sqlite3` directly.
// Rationale:
//  - `package:sqlite3` *is* resolvable here (verified: sqlite3 2.9.4 sits in
//    .dart_tool/package_config.json as a transitive dep of drift /
//    sqlite3_flutter_libs), so `import 'package:sqlite3/sqlite3.dart'` would
//    analyze. We deliberately avoided it anyway because opening a raw
//    `sqlite3.open(path)` in `flutter test` on Windows needs its own dynamic
//    -library init path, while drift's `NativeDatabase` already handles native
//    init via sqlite3_flutter_libs (proven: NativeDatabase.memory() works on
//    this host). Using a throwaway GeneratedDatabase with zero tables gives us
//    a raw executor (customStatement/customSelect) over NativeDatabase(file)
//    with zero new dependencies and identical on-disk bytes.
//  - Old v3 shape reconstructed from lib/database/database.dart onUpgrade:
//    bills.amount REAL + payments.amount REAL (converted via
//    CAST(ROUND(amount * 100) AS INTEGER) into amount_paise), plus a legacy
//    bank_transactions table that v4 drops. All other columns mirror the v4
//    schema in lib/database/tables.dart (drift DateTime columns are stored as
//    INTEGER unix-seconds; see watchAllBillsWithPaid which multiplies by 1000).
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billmed/database/database.dart';

/// Throwaway raw executor over a file. Zero tables on purpose: we issue our
/// own DDL via customStatement to fabricate the legacy v3 layout.
class _RawV3Db extends GeneratedDatabase {
  _RawV3Db(super.executor);

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  int get schemaVersion => 3;
}

Future<String> _buildV3File() async {
  final dir = await Directory.systemTemp.createTemp('billmed_mig_');
  final path = '${dir.path}${Platform.pathSeparator}old.db';
  final probe = _RawV3Db(NativeDatabase(File(path)));

  // Distributors: identical in v3 and v4.
  await probe.customStatement('''
    CREATE TABLE distributors (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      company TEXT,
      phone TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''');

  // Bills v3: REAL `amount` instead of INTEGER `amount_paise`.
  await probe.customStatement('''
    CREATE TABLE bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      distributor_id INTEGER NOT NULL REFERENCES distributors (id),
      bill_number TEXT NOT NULL,
      bill_date INTEGER NOT NULL,
      amount REAL NOT NULL,
      notes TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''');

  // Payments v3: REAL `amount` instead of INTEGER `amount_paise`.
  await probe.customStatement('''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL REFERENCES bills (id),
      payment_date INTEGER NOT NULL,
      amount REAL NOT NULL,
      mode TEXT NOT NULL,
      reference_no TEXT,
      notes TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''');

  // Legacy table the v4 migration must drop.
  await probe.customStatement('''
    CREATE TABLE bank_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      note TEXT
    )
  ''');
  await probe.customStatement(
      "INSERT INTO bank_transactions (note) VALUES ('legacy')");

  // Seed: one distributor + bill 1000.75 + payment 500.50.
  // DateTime cols are INTEGER unix-seconds.
  final billDateSec = DateTime(2026, 1, 10).millisecondsSinceEpoch ~/ 1000;
  final payDateSec = DateTime(2026, 1, 20).millisecondsSinceEpoch ~/ 1000;
  final nowSec = DateTime(2026, 1, 5).millisecondsSinceEpoch ~/ 1000;
  await probe.customStatement(
    "INSERT INTO distributors (name, created_at) VALUES ('Mig Supplier', $nowSec)",
  );
  await probe.customStatement(
    'INSERT INTO bills (distributor_id, bill_number, bill_date, amount, created_at) '
    "VALUES (1, 'MIG-001', $billDateSec, 1000.75, $nowSec)",
  );
  await probe.customStatement(
    'INSERT INTO payments (bill_id, payment_date, amount, mode, created_at) '
    "VALUES (1, $payDateSec, 500.50, 'Cash', $nowSec)",
  );

  await probe.customStatement('PRAGMA user_version = 3');
  final check = await probe.customSelect('PRAGMA user_version').getSingle();
  expect(check.read<int>('user_version'), 3,
      reason: 'precondition: fixture must be stamped v3');

  await probe.close();
  return path;
}

void main() {
  test('v3 file migrates to v4: paise conversion, table drop, indexes, FK',
      () async {
    final path = await _buildV3File();
    addTearDown(() async {
      try {
        await Directory(File(path).parent.path).delete(recursive: true);
      } catch (_) {}
    });

    final db = BillMedDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    // Trigger open + onUpgrade(3 → 4) with a real query.
    final bills = await db.getAllBills();
    expect(bills, hasLength(1));
    expect(bills.first.billNumber, 'MIG-001');
    expect(bills.first.amountPaise, 100075,
        reason: 'CAST(ROUND(1000.75 * 100)) must be 100075');

    final payments = await db.getPaymentsByBill(bills.first.id);
    expect(payments, hasLength(1));
    expect(payments.first.amountPaise, 50050,
        reason: 'CAST(ROUND(500.50 * 100)) must be 50050');

    // Paid math still works after migration.
    expect(await db.getTotalPaidForBill(bills.first.id), 50050);
    final bp = await db.getBillWithPaid(bills.first.id);
    expect(bp!.remainingPaise, 50025);

    // bank_transactions must be gone.
    final bank = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bank_transactions'",
        )
        .get();
    expect(bank, isEmpty, reason: 'v4 migration drops bank_transactions');

    // Schema version bumped to 4.
    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.read<int>('user_version'), 4);

    // v4 indexes exist.
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index'",
        )
        .get();
    final names = idx.map((r) => r.read<String>('name')).toSet();
    for (final want in const [
      'idx_bills_distributor',
      'idx_bills_bill_date',
      'idx_payments_bill',
      'idx_payments_payment_date',
    ]) {
      expect(names, contains(want), reason: 'missing index $want');
    }

    // Foreign keys enforced (beforeOpen pragma).
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.read<int>('foreign_keys'), 1);
  });

  test('v1 file migrates to v4 with exact paise', () async {
    final path = await _buildLegacyFile(versionStamp: 1);
    addTearDown(() async {
      try {
        await Directory(File(path).parent.path).delete(recursive: true);
      } catch (_) {}
    });

    await _expectMigratedToV4(path);
  });

  test('v2 file migrates to v4 with exact paise', () async {
    final path = await _buildLegacyFile(versionStamp: 2);
    addTearDown(() async {
      try {
        await Directory(File(path).parent.path).delete(recursive: true);
      } catch (_) {}
    });

    await _expectMigratedToV4(path);
  });

  test('indexed-v3 with pre-existing indexes migrates cleanly to v4', () async {
    // Regression: _createIndexes() used plain CREATE INDEX, so any on-device
    // DB that already carried the 4 indexes crashed mid-upgrade with
    // 'already exists'. Fixed with IF NOT EXISTS — this must reach v4.
    final path = await _buildLegacyFile(versionStamp: 3, withIndexes: true);
    addTearDown(() async {
      try {
        await Directory(File(path).parent.path).delete(recursive: true);
      } catch (_) {}
    });

    await _expectMigratedToV4(path);
  });
}

/// Builds a legacy-shape file (same old layout as [_buildV3File]: REAL
/// `amount` cols + legacy `bank_transactions`) stamped with [versionStamp].
/// When [withIndexes] is true, the 4 production indexes (exact names/columns
/// from lib/database/database.g.dart) are pre-created BEFORE the upgrade.
Future<String> _buildLegacyFile({
  required int versionStamp,
  bool withIndexes = false,
}) async {
  final dir =
      await Directory.systemTemp.createTemp('billmed_mig_v${versionStamp}_');
  final path = '${dir.path}${Platform.pathSeparator}old.db';
  final probe = _RawV3Db(NativeDatabase(File(path)));

  await probe.customStatement('''
    CREATE TABLE distributors (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      company TEXT,
      phone TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''');
  await probe.customStatement('''
    CREATE TABLE bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      distributor_id INTEGER NOT NULL REFERENCES distributors (id),
      bill_number TEXT NOT NULL,
      bill_date INTEGER NOT NULL,
      amount REAL NOT NULL,
      notes TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''');
  await probe.customStatement('''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL REFERENCES bills (id),
      payment_date INTEGER NOT NULL,
      amount REAL NOT NULL,
      mode TEXT NOT NULL,
      reference_no TEXT,
      notes TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''');
  await probe.customStatement('''
    CREATE TABLE bank_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      note TEXT
    )
  ''');
  await probe.customStatement(
      "INSERT INTO bank_transactions (note) VALUES ('legacy')");

  final billDateSec = DateTime(2026, 1, 10).millisecondsSinceEpoch ~/ 1000;
  final payDateSec = DateTime(2026, 1, 20).millisecondsSinceEpoch ~/ 1000;
  final nowSec = DateTime(2026, 1, 5).millisecondsSinceEpoch ~/ 1000;
  await probe.customStatement(
    "INSERT INTO distributors (name, created_at) VALUES ('Mig Supplier', $nowSec)",
  );
  await probe.customStatement(
    'INSERT INTO bills (distributor_id, bill_number, bill_date, amount, created_at) '
    "VALUES (1, 'MIG-001', $billDateSec, 1000.75, $nowSec)",
  );
  await probe.customStatement(
    'INSERT INTO payments (bill_id, payment_date, amount, mode, created_at) '
    "VALUES (1, $payDateSec, 500.50, 'Cash', $nowSec)",
  );

  if (withIndexes) {
    await probe.customStatement(
        'CREATE INDEX idx_bills_distributor ON bills (distributor_id)');
    await probe.customStatement(
        'CREATE INDEX idx_bills_bill_date ON bills (bill_date)');
    await probe.customStatement(
        'CREATE INDEX idx_payments_bill ON payments (bill_id)');
    await probe.customStatement(
        'CREATE INDEX idx_payments_payment_date ON payments (payment_date)');
  }

  await probe.customStatement('PRAGMA user_version = $versionStamp');
  final check = await probe.customSelect('PRAGMA user_version').getSingle();
  expect(check.read<int>('user_version'), versionStamp,
      reason: 'precondition: fixture must be stamped v$versionStamp');

  await probe.close();
  return path;
}

/// Opens [path] via BillMedDatabase (triggering onUpgrade to v4) and asserts
/// the full post-migration contract: exact paise, table drop, indexes, FK.
Future<void> _expectMigratedToV4(String path) async {
  final db = BillMedDatabase(NativeDatabase(File(path)));
  addTearDown(db.close);

  final bills = await db.getAllBills();
  expect(bills, hasLength(1));
  expect(bills.first.billNumber, 'MIG-001');
  expect(bills.first.amountPaise, 100075,
      reason: 'CAST(ROUND(1000.75 * 100)) must be 100075');

  final payments = await db.getPaymentsByBill(bills.first.id);
  expect(payments, hasLength(1));
  expect(payments.first.amountPaise, 50050,
      reason: 'CAST(ROUND(500.50 * 100)) must be 50050');
  expect(await db.getTotalPaidForBill(bills.first.id), 50050);
  final bp = await db.getBillWithPaid(bills.first.id);
  expect(bp!.remainingPaise, 50025);

  final bank = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bank_transactions'",
      )
      .get();
  expect(bank, isEmpty, reason: 'v4 migration drops bank_transactions');

  final ver = await db.customSelect('PRAGMA user_version').getSingle();
  expect(ver.read<int>('user_version'), 4);

  final idx = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      )
      .get();
  final names = idx.map((r) => r.read<String>('name')).toSet();
  for (final want in const [
    'idx_bills_distributor',
    'idx_bills_bill_date',
    'idx_payments_bill',
    'idx_payments_payment_date',
  ]) {
    expect(names, contains(want), reason: 'missing index $want');
  }

  final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
  expect(fk.read<int>('foreign_keys'), 1);
}
