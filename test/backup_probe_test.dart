// Real-file probes for BackupService.validateBackupFile — the gate that
// decides whether a picked file may replace the live ledger.
//
// Every case below is an actual file on disk opened by real SQLite: drift's
// NativeDatabase for fixtures and probe checks, BillMedDatabase for the
// "is it genuinely restorable?" reads. No mocks, no widgets, and therefore no
// `pumpAndSettle` anywhere in this file.
//
// validateBackupFile is @visibleForTesting because importBackup() itself needs
// the platform file picker. It is the pure decision that follows the pick, and
// the only thing standing between a picked file and billmed.db — so an
// over-permissive result here is a data-loss/bricking bug, and an over-strict
// one silently destroys the user's only way back to their ledger.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billmed/database/database.dart';
import 'package:billmed/services/backup_service.dart';

/// Throwaway raw executor over a file: zero drift tables, and — crucially —
/// `enableMigrations: false`, so drift neither reads nor writes `user_version`
/// and can never silently "repair" a fixture that is deliberately malformed.
class _RawDb extends GeneratedDatabase {
  _RawDb(super.executor);

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  int get schemaVersion => 4;
}

/// A file inside a fresh temp directory that is removed recursively when the
/// current test ends. Fixtures are never written outside systemTemp.
File _tempFile(String name) {
  final dir = Directory.systemTemp.createTempSync('billmed_probe_');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  return File('${dir.path}${Platform.pathSeparator}$name');
}

_RawDb _raw(File file) => _RawDb(NativeDatabase(file, enableMigrations: false));

int _epochSeconds(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

// ─── Column inventories ─────────────────────────────────────────────────────
// The v4 shape below mirrors lib/database/tables.dart (drift DateTime columns
// are stored as INTEGER unix-seconds). Fixtures drop a single column from these
// lists to hand-craft exactly the defect a test is about.

const List<String> _v4DistributorColumns = [
  'id INTEGER PRIMARY KEY AUTOINCREMENT',
  'name TEXT NOT NULL',
  'company TEXT',
  'phone TEXT',
  "created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))",
];

const List<String> _v4BillsColumns = [
  'id INTEGER PRIMARY KEY AUTOINCREMENT',
  'distributor_id INTEGER NOT NULL REFERENCES distributors (id)',
  'bill_number TEXT NOT NULL',
  'bill_date INTEGER NOT NULL',
  'amount_paise INTEGER NOT NULL',
  'notes TEXT',
  "created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))",
];

const List<String> _v4PaymentsColumns = [
  'id INTEGER PRIMARY KEY AUTOINCREMENT',
  'bill_id INTEGER NOT NULL REFERENCES bills (id)',
  'payment_date INTEGER NOT NULL',
  'amount_paise INTEGER NOT NULL',
  'mode TEXT NOT NULL',
  'reference_no TEXT',
  'notes TEXT',
  "created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))",
];

/// Distributors are byte-identical in v1–v4.
const List<String> _legacyDistributorColumns = _v4DistributorColumns;

/// The pre-v4 money column is REAL `amount`, holding rupees.
const List<String> _legacyBillsColumns = [
  'id INTEGER PRIMARY KEY AUTOINCREMENT',
  'distributor_id INTEGER NOT NULL REFERENCES distributors (id)',
  'bill_number TEXT NOT NULL',
  'bill_date INTEGER NOT NULL',
  'amount REAL NOT NULL',
  'notes TEXT',
  "created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))",
];

const List<String> _legacyPaymentsColumns = [
  'id INTEGER PRIMARY KEY AUTOINCREMENT',
  'bill_id INTEGER NOT NULL REFERENCES bills (id)',
  'payment_date INTEGER NOT NULL',
  'amount REAL NOT NULL',
  'mode TEXT NOT NULL',
  'reference_no TEXT',
  'notes TEXT',
  "created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))",
];

/// Creates [table] from [columns], optionally leaving one column out.
/// [without] must actually exist in the list — a typo would otherwise produce a
/// fixture that is missing nothing and silently prove nothing.
Future<void> _createTable(
  _RawDb probe,
  String table,
  List<String> columns, {
  String? without,
}) async {
  if (without != null) {
    expect(
      columns.any((column) => column.startsWith('$without ')),
      isTrue,
      reason: 'fixture precondition: $table must declare "$without" to drop it',
    );
  }
  final kept =
      columns.where((column) => !column.startsWith('$without ')).toList();
  await probe
      .customStatement('CREATE TABLE $table (\n  ${kept.join(',\n  ')}\n)');
}

/// A complete v4-shaped file. Each `...Without` removes exactly one column the
/// app's drift mapper reads.
Future<_RawDb> _openV4Fixture(
  File file, {
  String? billsWithout,
  String? paymentsWithout,
  String? distributorsWithout,
}) async {
  final probe = _raw(file);
  await _createTable(probe, 'distributors', _v4DistributorColumns,
      without: distributorsWithout);
  await _createTable(probe, 'bills', _v4BillsColumns, without: billsWithout);
  await _createTable(probe, 'payments', _v4PaymentsColumns,
      without: paymentsWithout);
  return probe;
}

/// One supplier row, with plain INSERTs so no fixture depends on the app's own
/// write path.
Future<void> _seedDistributor(_RawDb probe) async {
  final now = _epochSeconds(DateTime(2026, 1, 5));
  await probe.customStatement(
      'INSERT INTO distributors (name, company, phone, created_at) '
      "VALUES ('Apex Medical', 'Apex Pharma', '9876543210', $now)");
}

/// One bill row (₹1,000.75). Pass `withBillNumber: false` for a fixture whose
/// `bills` table has no such column — the row then simply has none to read.
Future<void> _seedBill(_RawDb probe, {bool withBillNumber = true}) async {
  final now = _epochSeconds(DateTime(2026, 1, 5));
  final billDate = _epochSeconds(DateTime(2026, 1, 10));
  if (withBillNumber) {
    await probe.customStatement(
        'INSERT INTO bills (distributor_id, bill_number, bill_date, amount_paise, notes, created_at) '
        "VALUES (1, 'INV-1001', $billDate, 100075, 'probe bill', $now)");
  } else {
    await probe.customStatement(
        'INSERT INTO bills (distributor_id, bill_date, amount_paise, notes, created_at) '
        "VALUES (1, $billDate, 100075, 'probe bill', $now)");
  }
}

/// One payment row (₹500.50). Pass `withAmountPaise: false` for a fixture whose
/// `payments` table has no such column.
Future<void> _seedPayment(_RawDb probe, {bool withAmountPaise = true}) async {
  final now = _epochSeconds(DateTime(2026, 1, 5));
  final payDate = _epochSeconds(DateTime(2026, 1, 20));
  if (withAmountPaise) {
    await probe.customStatement(
        'INSERT INTO payments (bill_id, payment_date, amount_paise, mode, reference_no, notes, created_at) '
        "VALUES (1, $payDate, 50050, 'Cash', 'RCPT-7', NULL, $now)");
  } else {
    await probe.customStatement(
        'INSERT INTO payments (bill_id, payment_date, mode, reference_no, notes, created_at) '
        "VALUES (1, $payDate, 'Cash', 'RCPT-7', NULL, $now)");
  }
}

/// One distributor + bill ₹1,000.75 + payment ₹500.50.
Future<void> _seedV4(_RawDb probe) async {
  await _seedDistributor(probe);
  await _seedBill(probe);
  await _seedPayment(probe);
}

/// Legacy (v1–v3) shape: the same three tables with the money column still
/// named `amount`, holding rupees as REAL — exactly what database.dart's
/// onUpgrade reads through `CAST(ROUND(amount * 100) AS INTEGER)`.
Future<_RawDb> _openLegacyFixture(File file) async {
  final probe = _raw(file);
  await _createTable(probe, 'distributors', _legacyDistributorColumns);
  await _createTable(probe, 'bills', _legacyBillsColumns);
  await _createTable(probe, 'payments', _legacyPaymentsColumns);
  return probe;
}

Future<void> _seedLegacy(_RawDb probe) async {
  final now = _epochSeconds(DateTime(2026, 1, 5));
  final billDate = _epochSeconds(DateTime(2026, 1, 10));
  final payDate = _epochSeconds(DateTime(2026, 1, 20));
  await probe
      .customStatement("INSERT INTO distributors (name, company, created_at) "
          "VALUES ('Legacy Supplier', 'Legacy Pharma', $now)");
  await probe.customStatement(
      'INSERT INTO bills (distributor_id, bill_number, bill_date, amount, created_at) '
      "VALUES (1, 'LEG-001', $billDate, 1000.75, $now)");
  await probe.customStatement(
      'INSERT INTO payments (bill_id, payment_date, amount, mode, created_at) '
      "VALUES (1, $payDate, 500.50, 'Cash', $now)");
}

Future<void> _stamp(_RawDb probe, int version) async {
  await probe.customStatement('PRAGMA user_version = $version');
  final row = await probe.customSelect('PRAGMA user_version').getSingle();
  expect(row.read<int>('user_version'), version,
      reason: 'fixture precondition: file must be stamped v$version');
}

Future<Set<String>> _columnsOf(_RawDb probe, String table) async {
  final rows = await probe.customSelect('PRAGMA table_info($table)').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _tablesOf(_RawDb probe) async {
  final rows = await probe
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

/// Positive control for the hand-written v4 fixtures: the same builders with no
/// deliberate defect must produce a file the gate accepts. A test that then
/// adds exactly one defect proves its `false` comes from that defect rather
/// than from a mistake in the fixture DDL.
Future<void> _expectV4FixtureControlAccepted(File file) async {
  final probe = await _openV4Fixture(file);
  await _seedV4(probe);
  await _stamp(probe, 4);
  await probe.close();

  expect(
    await BackupService.validateBackupFile(file.path),
    isTrue,
    reason: 'fixture precondition: this hand-written v4 file, without the '
        'defect under test, is a valid backup',
  );
}

void main() {
  test('a freshly created BillMed v4 database file is accepted', () async {
    final file = _tempFile('fresh_v4.db');

    // Written by the app's own database class: the most realistic backup there
    // is, produced the same way exportBackup's VACUUM INTO snapshot is.
    final live = BillMedDatabase(NativeDatabase(file));
    final distId = await live.addDistributor(DistributorsCompanion.insert(
      name: 'Apex Medical',
      company: const Value('Apex Pharma'),
      phone: const Value('9876543210'),
    ));
    final billId = await live.addBill(BillsCompanion.insert(
      distributorId: distId,
      billNumber: 'INV-1001',
      billDate: DateTime(2026, 1, 10),
      amountPaise: 100075,
      notes: const Value('probe bill'),
    ));
    await live.addPayment(PaymentsCompanion.insert(
      billId: billId,
      paymentDate: DateTime(2026, 1, 20),
      amountPaise: 50050,
      mode: 'Cash',
      referenceNo: const Value('RCPT-7'),
    ));
    await live.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isTrue,
      reason: 'a backup this app just wrote must pass its own restore gate — '
          'otherwise every export is a dead end',
    );

    // Accepted is not enough: prove the accepted file is genuinely restorable.
    final restored = BillMedDatabase(NativeDatabase(file));
    addTearDown(restored.close);
    final distributors = await restored.watchAllDistributors().first;
    expect(distributors, hasLength(1),
        reason: 'restored ledger must still hold the seeded distributor');
    expect(distributors.single.name, 'Apex Medical');
    final bills = await restored.getAllBills();
    expect(bills, hasLength(1),
        reason: 'restored ledger must still hold the seeded bill');
    expect(bills.single.billNumber, 'INV-1001');
    expect(bills.single.amountPaise, 100075,
        reason: 'paise must survive the round trip exactly');
    final payments = await restored.getPaymentsByBill(bills.single.id);
    expect(payments, hasLength(1),
        reason: 'restored ledger must still hold the seeded payment');
    expect(payments.single.amountPaise, 50050);
    expect(await restored.getTotalPaidForBill(bills.single.id), 50050);
  });

  test('a v4 file whose bills table is missing bill_number is rejected',
      () async {
    final file = _tempFile('v4_bills_without_bill_number.db');
    await _expectV4FixtureControlAccepted(_tempFile('v4_control.db'));
    final probe = await _openV4Fixture(file, billsWithout: 'bill_number');
    // Populated, not empty: a supplier and a bill whose row has no
    // bill_number to read.
    await _seedDistributor(probe);
    await _seedBill(probe, withBillNumber: false);
    await _stamp(probe, 4);
    await probe.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason: 'the drift mapper reads bills.bill_number, so a v4 file lacking '
          'it would throw on every later query once restored',
    );
  });

  test('a v4 file whose payments table is missing amount_paise is rejected',
      () async {
    final file = _tempFile('v4_payments_without_amount_paise.db');
    await _expectV4FixtureControlAccepted(_tempFile('v4_control.db'));
    final probe = await _openV4Fixture(file, paymentsWithout: 'amount_paise');
    // Populated, not empty: a supplier, a bill, and a payment row that carries
    // no amount_paise.
    await _seedDistributor(probe);
    await _seedBill(probe);
    await _seedPayment(probe, withAmountPaise: false);
    await _stamp(probe, 4);
    await probe.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason: 'payments.amount_paise is the only money column the app reads '
          'and sums; without it the file opens but every balance query throws',
    );
  });

  test('a v4 file whose distributors table is missing name is rejected',
      () async {
    final file = _tempFile('v4_distributors_without_name.db');
    await _expectV4FixtureControlAccepted(_tempFile('v4_control.db'));
    final probe = await _openV4Fixture(file, distributorsWithout: 'name');
    await _stamp(probe, 4);
    await probe.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason: 'distributors used to be left unchecked entirely, so a file '
          'whose supplier rows cannot be read still passed the gate',
    );
  });

  /// THE BRICK CASE.
  ///
  /// A file stamped `user_version = 1` whose bills/payments carry only
  /// `amount` (no `distributor_id`, no `bill_number`, …) used to be accepted by
  /// this probe as a "legacy" backup. Restore then copied it over the live
  /// ledger, and on the very next launch BillMedDatabase's onUpgrade ran
  /// `TableMigration(bills)` / `TableMigration(payments)` from database.dart,
  /// whose `INSERT … SELECT` names every v4 column — columns this file does not
  /// have. The migration threw, so *every* later open of the app threw, and
  /// because the in-app safety copy needs a working live database the user lost
  /// the way back too: a permanent brick from one picked file, with no error
  /// the user could act on.
  ///
  /// The gate must therefore refuse a legacy file that the app's own migration
  /// could not read, not merely one that SQLite can open.
  test('a v1 file carrying only `amount` (no v4 columns) is rejected',
      () async {
    final file = _tempFile('v1_amount_only.db');
    final probe = _raw(file);

    // Distributors: id + name + created_at only (no company/phone).
    await probe.customStatement('''
      CREATE TABLE distributors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');
    // Bills: money only — no distributor_id, no bill_number, no bill_date.
    await probe.customStatement('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');
    await probe.customStatement('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');
    final now = _epochSeconds(DateTime(2026, 1, 5));
    await probe.customStatement(
        "INSERT INTO distributors (name, created_at) VALUES ('Legacy', $now)");
    await probe.customStatement(
        'INSERT INTO bills (amount, created_at) VALUES (10.5, $now)');
    await probe.customStatement(
        'INSERT INTO payments (amount, created_at) VALUES (5.25, $now)');
    await _stamp(probe, 1);

    // Preconditions: the file is a healthy, in-range v1 SQLite database. The
    // only thing wrong with it is the column set — so a `false` below can only
    // come from the column check, not from an earlier or unrelated refusal.
    expect(await _tablesOf(probe),
        containsAll(['distributors', 'bills', 'payments']),
        reason: 'fixture precondition: the three tables exist');
    final integrity =
        await probe.customSelect('PRAGMA integrity_check').getSingle();
    expect(integrity.read<String>('integrity_check'), 'ok',
        reason: 'fixture precondition: the file is structurally sound');
    expect(await _columnsOf(probe, 'bills'), contains('amount'));
    expect(await _columnsOf(probe, 'bills'), isNot(contains('distributor_id')));
    expect(await _columnsOf(probe, 'bills'), isNot(contains('bill_number')));
    await probe.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason: 'accepting this file makes the app unable to open its own '
          'database ever again: onUpgrade would fail on every launch',
    );
  });

  test(
      'a legacy v1 file with the full legacy column set is accepted and still '
      'migrates to v4', () async {
    final file = _tempFile('v1_full_legacy.db');
    final probe = await _openLegacyFixture(file);
    await _seedLegacy(probe);
    await _stamp(probe, 1);
    await probe.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isTrue,
      reason: 'a genuine pre-v4 backup is exactly what restore exists for; '
          'refusing it would strand users on old versions',
    );

    // Accepted must mean "the app can really open it": restoring copies the
    // file to billmed.db and the next launch migrates it in place.
    final db = BillMedDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final bills = await db.getAllBills();
    expect(bills, hasLength(1),
        reason: 'the migrated ledger must still hold the legacy bill');
    expect(bills.single.billNumber, 'LEG-001');
    expect(bills.single.amountPaise, 100075,
        reason: r'₹1,000.75 must become exactly 100075 paise');

    final payments = await db.getPaymentsByBill(bills.single.id);
    expect(payments, hasLength(1),
        reason: 'the migrated ledger must still hold the legacy payment');
    expect(payments.single.amountPaise, 50050,
        reason: r'₹500.50 must become exactly 50050 paise');

    expect(await db.getTotalPaidForBill(bills.single.id), 50050);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 4,
        reason: 'opening the accepted file must complete the v1 → v4 upgrade');
  });

  test('a file carrying a CREATE TRIGGER or a CREATE VIEW is rejected',
      () async {
    final file = _tempFile('v4_with_foreign_object.db');
    final probe = await _openV4Fixture(file);
    await _seedV4(probe);
    await _stamp(probe, 4);

    // Control: the identical fixture with no trigger and no view is accepted,
    // so the two `false` results below can only come from those objects.
    expect(
      await BackupService.validateBackupFile(file.path),
      isTrue,
      reason: 'fixture precondition: this file is a valid v4 backup until a '
          'trigger or view is added',
    );

    await probe.customStatement('''
      CREATE TRIGGER bills_touch AFTER INSERT ON bills
      BEGIN
        UPDATE bills SET notes = notes WHERE id = NEW.id;
      END
    ''');
    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason: 'BillMed creates no triggers, so a trigger could only ride into '
          'the live ledger as foreign logic executed on every write',
    );

    await probe.customStatement('DROP TRIGGER bills_touch');
    await probe.customStatement(
        'CREATE VIEW distributor_names AS SELECT id, name FROM distributors');
    await probe.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason: 'BillMed creates no views either: a view is foreign schema that '
          'the migrations never expected',
    );
  });

  test(
      'a non-SQLite file, and a SQLite file with user_version 0 or 5, are '
      'rejected', () async {
    // Plain text, comfortably over the 100-byte size floor.
    final text = _tempFile('notes.db');
    text.writeAsStringSync(
        'Grocery list: milk, rice, dal, atta, oil, salt, sugar, tea, soap.\n'
        'Grocery list: milk, rice, dal, atta, oil, salt, sugar, tea, soap.\n'
        'Grocery list: milk, rice, dal, atta, oil, salt, sugar, tea, soap.\n');

    // A correct 15-byte magic over nothing but zeros: the header check alone
    // must not be enough, only a real open can accept a file.
    final fakeHeader = _tempFile('fake_header.db');
    fakeHeader.writeAsBytesSync(<int>[
      ...'SQLite format 3'.codeUnits,
      0,
      ...List<int>.filled(200, 0),
    ]);
    expect(
      String.fromCharCodes(fakeHeader.readAsBytesSync().sublist(0, 15)),
      'SQLite format 3',
      reason: 'fixture precondition: the magic bytes are valid, so only a real '
          'SQLite open can reject this file',
    );

    // One real v4 file, re-stamped between checks: at v4 it is a valid backup,
    // and the only difference afterwards is the declared schema version.
    final versionFile = _tempFile('v4_user_version.db');
    final versionProbe = await _openV4Fixture(versionFile);
    await _seedV4(versionProbe);
    await _stamp(versionProbe, 4);
    expect(
      await BackupService.validateBackupFile(versionFile.path),
      isTrue,
      reason: 'fixture precondition: the same file stamped 4 is accepted, so '
          'the version is the only thing under test below',
    );

    final v0 =
        await versionProbe.customSelect('PRAGMA user_version').getSingle();
    expect(v0.read<int>('user_version'), 4,
        reason: 'fixture precondition: the file starts out stamped v4');
    await _stamp(versionProbe, 0);
    expect(
      await BackupService.validateBackupFile(versionFile.path),
      isFalse,
      reason: 'user_version 0 means the schema was never declared, so the app '
          'cannot know what it would be reading',
    );

    await _stamp(versionProbe, 5);
    await versionProbe.close();

    expect(
      await BackupService.validateBackupFile(text.path),
      isFalse,
      reason: 'plain text is not a database, whatever it is named',
    );
    expect(
      await BackupService.validateBackupFile(fakeHeader.path),
      isFalse,
      reason: 'a file that only pretends to carry the SQLite magic must not '
          'reach the live path',
    );
    expect(
      await BackupService.validateBackupFile(versionFile.path),
      isFalse,
      reason: 'a version newer than this build understands (5 > 4) may carry '
          'columns and constraints the app would silently misinterpret',
    );
  });

  test('a file whose money column holds an absurd value is rejected', () async {
    const absurd = 9223372036854775807; // int64 max paise
    final file = _tempFile('v4_absurd_amount.db');
    final probe = await _openV4Fixture(file);
    await _seedV4(probe);
    await _stamp(probe, 4);

    // Control: the same fixture holding only ordinary money is accepted.
    expect(
      await BackupService.validateBackupFile(file.path),
      isTrue,
      reason: 'fixture precondition: the file is a valid backup before the '
          'absurd row is added',
    );

    final payDate = _epochSeconds(DateTime(2026, 1, 21));
    for (var i = 0; i < 2; i++) {
      await probe.customStatement(
          'INSERT INTO payments (bill_id, payment_date, amount_paise, mode) '
          "VALUES (1, $payDate, $absurd, 'Cash')");
    }

    // Preconditions: the value really is stored, and aggregating it really
    // does overflow — which is the reason the bound exists at all.
    final worst = await probe
        .customSelect('SELECT MAX(amount_paise) AS worst FROM payments')
        .getSingle();
    expect(worst.read<int>('worst'), absurd,
        reason: 'fixture precondition: SQLite must hold the absurd value');
    await expectLater(
      probe
          .customSelect('SELECT SUM(amount_paise) AS total FROM payments')
          .get(),
      throwsA(anything),
      reason: 'SUM() over such rows overflows, and getTotalPaidForBill / '
          'watchAllBillsWithPaid are built on exactly that SUM',
    );
    await probe.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason: 'no shop bill reaches ₹100 crore; such rows can only break every '
          'aggregate the screens read',
    );
  });

  test('a zero-byte or truncated file is rejected', () async {
    final empty = _tempFile('empty.db');
    empty.writeAsBytesSync(const <int>[]);

    final tiny = _tempFile('tiny.db');
    tiny.writeAsStringSync('SQLite format 3${List.filled(40, 'x').join()}');
    expect(tiny.lengthSync(), lessThan(100),
        reason: 'fixture precondition: this file is under the size floor');

    // A genuine v4 backup cut down to its first 200 bytes: long enough for the
    // size floor and the 15-byte magic, but every page behind the header is
    // gone.
    final source = _tempFile('source.db');
    final live = BillMedDatabase(NativeDatabase(source));
    await live
        .addDistributor(DistributorsCompanion.insert(name: 'Apex Medical'));
    await live.close();
    final full = source.readAsBytesSync();
    expect(full.length, greaterThan(200),
        reason: 'fixture precondition: there must be bytes to truncate away');
    final truncated = _tempFile('truncated.db');
    truncated.writeAsBytesSync(full.sublist(0, 200));

    // Control: the untruncated original is accepted, so the `false` below is
    // caused by the truncation and nothing else.
    expect(
      await BackupService.validateBackupFile(source.path),
      isTrue,
      reason: 'fixture precondition: the whole file is a valid backup',
    );

    expect(
      await BackupService.validateBackupFile(empty.path),
      isFalse,
      reason: 'a zero-byte file holds no ledger at all',
    );
    expect(
      await BackupService.validateBackupFile(tiny.path),
      isFalse,
      reason: 'a file smaller than 100 bytes cannot even hold a SQLite header, '
          'so it is a failed/partial write, not a backup',
    );
    expect(
      await BackupService.validateBackupFile(truncated.path),
      isFalse,
      reason: 'a truncated copy is the classic half-written backup: restoring '
          'it would replace a working ledger with unreadable pages',
    );
  });

  test('a v4 file whose money column allows NULL and holds one is rejected',
      () async {
    // A hostile file declares the column nullable, which is how a NULL gets
    // past a value-range check at all: `value < 0 OR value > bound` is never
    // true for NULL. The app reads that column as a non-nullable int.
    final nullable = _v4PaymentsColumns
        .map((column) => column == 'amount_paise INTEGER NOT NULL'
            ? 'amount_paise INTEGER'
            : column)
        .toList();
    expect(nullable.contains('amount_paise INTEGER'), isTrue,
        reason: 'fixture precondition: the money column must be nullable here');

    Future<void> build(File target, {required bool withNullRow}) async {
      final probe = _raw(target);
      await _createTable(probe, 'distributors', _v4DistributorColumns);
      await _createTable(probe, 'bills', _v4BillsColumns);
      await _createTable(probe, 'payments', nullable);
      await _seedV4(probe);
      if (withNullRow) {
        final stamp = _epochSeconds(DateTime(2026, 2, 1));
        await probe.customStatement(
            'INSERT INTO payments (bill_id, payment_date, amount_paise, mode, created_at) '
            "VALUES (1, $stamp, NULL, 'Cash', $stamp)");
      }
      await _stamp(probe, 4);
      await probe.close();
    }

    // Control: the same nullable declaration with no NULL row is accepted, so
    // the rejection below is caused by the value, not by the DDL.
    final control = _tempFile('v4_null_money_control.db');
    await build(control, withNullRow: false);
    expect(
      await BackupService.validateBackupFile(control.path),
      isTrue,
      reason: 'fixture precondition: nullable columns alone are fine',
    );

    final file = _tempFile('v4_null_money.db');
    await build(file, withNullRow: true);

    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason:
          'a NULL amount is unreadable by the app (int cast on null) yet is '
          'invisible to a range check — restoring it would replace a working '
          'ledger with one that throws on the first query',
    );
  });

  test('a v4 file whose money column is not an integer is rejected', () async {
    // INTEGER affinity keeps a fractional value as REAL, so this is the shape a
    // corrupted or hand-edited file actually produces.
    final fractional = _tempFile('v4_fractional_money.db');
    await _expectV4FixtureControlAccepted(fractional);
    final fractionalProbe = _raw(fractional);
    await fractionalProbe
        .customStatement('UPDATE payments SET amount_paise = 100.5');
    await fractionalProbe.close();

    expect(
      await BackupService.validateBackupFile(fractional.path),
      isFalse,
      reason:
          'money is integer paise everywhere; a REAL amount_paise type-errors '
          'in the app mapper after the ledger has been replaced',
    );

    final text = _tempFile('v4_text_money.db');
    await _expectV4FixtureControlAccepted(text);
    final textProbe = _raw(text);
    await textProbe
        .customStatement("UPDATE bills SET amount_paise = 'one thousand'");
    await textProbe.close();

    expect(
      await BackupService.validateBackupFile(text.path),
      isFalse,
      reason: 'a text amount cannot be summed or displayed as money',
    );
  });

  test('a legacy file whose amount is TEXT is rejected', () async {
    final file = _tempFile('legacy_text_amount.db');
    // Control: the same legacy fixture without the defect is accepted, so the
    // `false` below can only come from the text amount.
    final control = _tempFile('legacy_control.db');
    final controlProbe = await _openLegacyFixture(control);
    await _seedLegacy(controlProbe);
    await _stamp(controlProbe, 1);
    await controlProbe.close();
    expect(
      await BackupService.validateBackupFile(control.path),
      isTrue,
      reason: 'fixture precondition: this hand-written legacy file is a valid '
          'pre-v4 backup',
    );

    final probe = await _openLegacyFixture(file);
    await _seedLegacy(probe);
    await _stamp(probe, 1);
    await probe.customStatement("UPDATE payments SET amount = 'five hundred'");
    await probe.close();

    expect(
      await BackupService.validateBackupFile(file.path),
      isFalse,
      reason: 'the v1–v3 migration runs CAST(ROUND(amount * 100)) over this '
          'column, so a non-numeric amount cannot become valid paise',
    );
  });
}
