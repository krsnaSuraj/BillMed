import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/bill_status.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Distributors, Bills, Payments])
class BillMedDatabase extends _$BillMedDatabase {
  BillMedDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 4) {
            final bankExists = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bank_transactions'",
            ).get();
            if (bankExists.isNotEmpty) {
              await m.deleteTable('bank_transactions');
            }
            if (from >= 1) {
              // ignore: experimental_member_use
              await m.alterTable(TableMigration(
                bills,
                columnTransformer: {
                  bills.amountPaise: const CustomExpression(
                      'CAST(ROUND(amount * 100) AS INTEGER)'),
                },
              ));
              // ignore: experimental_member_use
              await m.alterTable(TableMigration(
                payments,
                columnTransformer: {
                  payments.amountPaise: const CustomExpression(
                      'CAST(ROUND(amount * 100) AS INTEGER)'),
                },
              ));
            }
            await _createIndexes();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
        },
      );

  /// Idempotent: real v1/v2/v3 databases already carry these indexes, and a
  /// plain CREATE INDEX would abort the upgrade with 'already exists'.
  Future<void> _createIndexes() async {
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_bills_distributor ON bills (distributor_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_bills_bill_date ON bills (bill_date)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_payments_bill ON payments (bill_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments (payment_date)');
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'billmed.db'));
      return NativeDatabase(file);
    });
  }

  // ─── Distributors ───────────────────────────────────────────────────────────

  Future<int> addDistributor(DistributorsCompanion entry) =>
      into(distributors).insert(entry);

  Future<void> updateDistributor(Distributor entry) =>
      update(distributors).replace(entry);

  // Test seam: production screens use the watched streams above.
  @visibleForTesting
  Future<Distributor?> getDistributor(int id) =>
      (select(distributors)..where((d) => d.id.equals(id))).getSingleOrNull();

  Stream<List<Distributor>> watchAllDistributors() =>
      select(distributors).watch();

  /// Deletes a distributor and ALL their bills and payments atomically.
  Future<void> deleteDistributorCascade(int distributorId) {
    return transaction(() async {
      await customStatement(
        'DELETE FROM payments WHERE bill_id IN (SELECT id FROM bills WHERE distributor_id = ?)',
        [distributorId],
      );
      await customStatement(
        'DELETE FROM bills WHERE distributor_id = ?',
        [distributorId],
      );
      await (delete(distributors)..where((d) => d.id.equals(distributorId)))
          .go();
    });
  }

  // ─── Bills ──────────────────────────────────────────────────────────────────

  Future<int> addBill(BillsCompanion entry) => into(bills).insert(entry);

  Future<void> updateBill(Bill entry) => update(bills).replace(entry);

  /// Deletes a bill and all its payments atomically.
  Future<void> deleteBillCascade(int billId) {
    return transaction(() async {
      await (delete(payments)..where((py) => py.billId.equals(billId))).go();
      await (delete(bills)..where((b) => b.id.equals(billId))).go();
    });
  }

  Future<bool> billNumberExistsForDistributor(
      int distributorId, String billNumber,
      {int? excludeBillId}) async {
    final query = selectOnly(bills)
      ..addColumns([bills.id])
      ..where(bills.distributorId.equals(distributorId) &
          bills.billNumber.upper().equals(billNumber.toUpperCase()));
    final rows = await query.get();
    for (final row in rows) {
      final id = row.read(bills.id)!;
      if (excludeBillId == null || id != excludeBillId) return true;
    }
    return false;
  }

  Future<Bill?> getBill(int id) =>
      (select(bills)..where((b) => b.id.equals(id))).getSingleOrNull();

  // Test seam: production screens filter the watched bills stream instead.
  @visibleForTesting
  Future<List<Bill>> getBillsByDistributor(int distId) =>
      (select(bills)..where((b) => b.distributorId.equals(distId))).get();

  // Test seam: used by migration tests to verify upgraded content.
  @visibleForTesting
  Future<List<Bill>> getAllBills() => select(bills).get();

  // ─── Payments ───────────────────────────────────────────────────────────────

  Future<int> addPayment(PaymentsCompanion entry) =>
      into(payments).insert(entry);

  Future<void> updatePayment(Payment entry) => update(payments).replace(entry);

  Future<int> deletePayment(int id) =>
      (delete(payments)..where((py) => py.id.equals(id))).go();

  Future<List<Payment>> getPaymentsByBill(int billId) =>
      (select(payments)..where((py) => py.billId.equals(billId))).get();

  Stream<List<Payment>> watchPaymentsByBill(int billId) => (select(payments)
        ..where((py) => py.billId.equals(billId)))
      .watch()
      .map((rows) =>
          [...rows]..sort((a, b) => a.paymentDate.compareTo(b.paymentDate)));

  // Test seam: production code aggregates through watched queries.
  @visibleForTesting
  Future<List<Payment>> getAllPayments() => select(payments).get();

  // ─── Aggregates (single source of truth, integer paise) ─────────────────────

  Future<int> getTotalPaidForBill(int billId) async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount_paise), 0) AS total FROM payments WHERE bill_id = ?',
      variables: [Variable.withInt(billId)],
    ).getSingle();
    return result.read<int>('total');
  }

  /// Every bill joined with its total-paid sum, watched live.
  Stream<List<BillPaid>> watchAllBillsWithPaid() {
    final query = customSelect(
      'SELECT b.id, b.distributor_id, b.bill_number, b.bill_date, b.amount_paise, '
      'b.notes, b.created_at, COALESCE(p.total_paid, 0) AS paid_total '
      'FROM bills b LEFT JOIN '
      '(SELECT bill_id, SUM(amount_paise) AS total_paid FROM payments GROUP BY bill_id) p '
      'ON p.bill_id = b.id ORDER BY b.bill_date DESC, b.id DESC',
      readsFrom: {bills, payments},
    );
    return query.watch().map((rows) {
      return rows.map((row) {
        final bill = Bill(
          id: row.read<int>('id'),
          distributorId: row.read<int>('distributor_id'),
          billNumber: row.read<String>('bill_number'),
          billDate: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('bill_date') * 1000),
          amountPaise: row.read<int>('amount_paise'),
          notes: row.readNullable<String>('notes'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('created_at') * 1000),
        );
        return BillPaid(bill: bill, paidPaise: row.read<int>('paid_total'));
      }).toList();
    });
  }

  Future<BillPaid?> getBillWithPaid(int billId) async {
    final bill = await getBill(billId);
    if (bill == null) return null;
    final paid = await getTotalPaidForBill(billId);
    return BillPaid(bill: bill, paidPaise: paid);
  }
}

class BillPaid {
  final Bill bill;
  final int paidPaise;

  BillPaid({required this.bill, required this.paidPaise});

  BillStatus get status => computeBillStatus(bill.amountPaise, paidPaise);

  int get remainingPaise {
    final diff = bill.amountPaise - paidPaise;
    return diff > 0 ? diff : 0;
  }

  bool get isOverdue =>
      isBillOverdue(bill.billDate, bill.amountPaise, paidPaise);
}
