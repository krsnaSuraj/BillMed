import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Distributors, Bills, Payments])
class BillMedDatabase extends _$BillMedDatabase {
  BillMedDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
    final result = await (select(payments)
          ..where((p) => p.billId.equals(billId))
          ..columns.add(payments.amount.sum()))
        .get();
    return (result.first.amount.sum ?? 0.0) as double;
  }

  Future<Map<int, double>> getTotalPaidForBills(List<int> billIds) async {
    if (billIds.isEmpty) return {};
    final result = await (select(payments)
          ..where((p) => p.billId.isIn(billIds))
          ..addColumns([payments.billId, payments.amount.sum()])
          ..groupBy([payments.billId]))
        .get();
    final map = <int, double>{};
    for (final r in result) {
      map[r.read(payments.billId) as int] =
          (r.read(payments.amount.sum()) ?? 0.0) as double;
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
}
