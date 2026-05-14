import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

final databaseProvider = Provider<BillMedDatabase>((ref) {
  final db = BillMedDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final distributorListProvider = FutureProvider<List<Distributor>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllDistributors();
});

final billStatusProvider = FutureProvider.family<String, int>((ref, billId) async {
  final db = ref.watch(databaseProvider);
  final bill = await db.getBill(billId);
  if (bill == null) return 'Unknown';
  final paid = await db.getTotalPaidForBill(billId);
  if (paid <= 0) return 'Unpaid';
  if (paid < bill.amount) return 'Partial';
  return 'Paid';
});

final paidAmountProvider = FutureProvider.family<double, int>((ref, billId) async {
  final db = ref.watch(databaseProvider);
  return db.getTotalPaidForBill(billId);
});
