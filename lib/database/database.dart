import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Distributors, Bills, Payments, BankTransactions])
class BillMedDatabase extends _$BillMedDatabase {
  BillMedDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(bankTransactions);
      }
      if (from < 3) {
        await m.addColumn(bankTransactions, bankTransactions.isReversal);
      }
    },
  );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'billmed.db'));
      return NativeDatabase(file);
    });
  }

  Future<int> addDistributor(DistributorsCompanion entry) =>
      into(distributors).insert(entry);

  Future<void> updateDistributor(Distributor entry) =>
      update(distributors).replace(entry);

  Future<int> deleteDistributor(int id) =>
      (delete(distributors)..where((d) => d.id.equals(id))).go();

  Future<Distributor?> getDistributor(int id) =>
      (select(distributors)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<List<Distributor>> getAllDistributors() => select(distributors).get();

  Stream<List<Distributor>> watchAllDistributors() =>
      select(distributors).watch();

  Future<int> addBill(BillsCompanion entry) => into(bills).insert(entry);

  Future<void> updateBill(Bill entry) => update(bills).replace(entry);

  Future<int> deleteBill(int id) =>
      (delete(bills)..where((b) => b.id.equals(id))).go();

  Future<Bill?> getBill(int id) =>
      (select(bills)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<List<Bill>> getBillsByDistributor(int distId) =>
      (select(bills)..where((b) => b.distributorId.equals(distId))).get();

  Stream<List<Bill>> watchBillsByDistributor(int distId) =>
      (select(bills)..where((b) => b.distributorId.equals(distId))).watch();

  Future<List<Bill>> getAllBills() => select(bills).get();

  Future<int> addPayment(PaymentsCompanion entry) => into(payments).insert(entry);

  Future<void> updatePayment(Payment entry) =>
      update(payments).replace(entry);

  Future<int> deletePayment(int id) =>
      (delete(payments)..where((p) => p.id.equals(id))).go();

  Future<List<Payment>> getPaymentsByBill(int billId) =>
      (select(payments)..where((p) => p.billId.equals(billId))).get();

  Stream<List<Payment>> watchPaymentsByBill(int billId) =>
      (select(payments)..where((p) => p.billId.equals(billId))).watch();

  Future<double> getTotalPaidForBill(int billId) async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM payments WHERE bill_id = ?',
      variables: [Variable.withInt(billId)],
    ).getSingle();
    return result.read<double>('total');
  }

  Future<Map<int, double>> getTotalPaidForBills(List<int> billIds) async {
    if (billIds.isEmpty) return {};
    final placeholders = billIds.map((_) => '?').join(',');
    final result = await customSelect(
      'SELECT bill_id, COALESCE(SUM(amount), 0) AS total '
      'FROM payments WHERE bill_id IN ($placeholders) GROUP BY bill_id',
      variables: billIds.map((id) => Variable.withInt(id)).toList(),
    ).get();
    final map = <int, double>{};
    for (final row in result) {
      map[row.read<int>('bill_id')] = row.read<double>('total');
    }
    return map;
  }

  Future<List<Bill>> getBillsWithPendingBalance() async {
    final allBills = await select(bills).get();
    if (allBills.isEmpty) return [];
    final billIds = allBills.map((b) => b.id).toList();
    final paidMap = await getTotalPaidForBills(billIds);
    return allBills.where((b) {
      final paid = paidMap[b.id] ?? 0.0;
      return paid < b.amount;
    }).toList();
  }

  // Bank Transactions CRUD
  Future<int> addBankTransaction(BankTransactionsCompanion entry) =>
      into(bankTransactions).insert(entry);

  Future<List<BankTransaction>> getAllBankTransactions() =>
      select(bankTransactions).get();

  Future<int> deleteAllBankTransactions() async {
    await delete(bankTransactions).go();
    return 0;
  }

  Future<int> addBankTransactionsBatch(List<BankTransactionsCompanion> entries) async {
    if (entries.isEmpty) return 0;
    await batch((b) {
      for (final entry in entries) {
        b.insert(bankTransactions, entry);
      }
    });
    return entries.length;
  }

  Future<Set<String>> getExistingTransactionKeys() async {
    final txns = await select(bankTransactions).get();
    return txns.map((t) =>
        '${t.txnDate.toIso8601String().substring(0, 10)}|${t.description}|${t.debit}|${t.credit}'
    ).toSet();
  }

  // All payments (for CA report cross-FY analysis)
  Future<List<Payment>> getAllPayments() => select(payments).get();
}
