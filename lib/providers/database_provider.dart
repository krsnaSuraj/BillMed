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

// ─── Real-time stream-based providers (auto-update without invalidation) ────

/// Watches payments in real-time — so paid status auto-updates everywhere
final paymentsStreamProvider =
    StreamProvider.family<List<Payment>, int>((ref, billId) {
  final db = ref.watch(databaseProvider);
  return db.watchPaymentsByBill(billId);
});

/// Watches bills for a distributor in real-time
final billsStreamProvider =
    StreamProvider.family<List<Bill>, int>((ref, distId) {
  final db = ref.watch(databaseProvider);
  return db.watchBillsByDistributor(distId);
});

// ─── Legacy FutureProviders (kept for backwards compat, still used in some places) ─

final billStatusProvider =
    FutureProvider.family<String, int>((ref, billId) async {
  final db = ref.watch(databaseProvider);
  // Watch the payments stream so this auto-refreshes on payment change
  ref.watch(paymentsStreamProvider(billId));
  final bill = await db.getBill(billId);
  if (bill == null) return 'Unknown';
  final paid = await db.getTotalPaidForBill(billId);
  if (paid <= 0) return 'Unpaid';
  if (paid < bill.amount) return 'Partial';
  return 'Paid';
});

final paidAmountProvider =
    FutureProvider.family<double, int>((ref, billId) async {
  final db = ref.watch(databaseProvider);
  // Watch the payments stream so this auto-refreshes on payment change
  ref.watch(paymentsStreamProvider(billId));
  return db.getTotalPaidForBill(billId);
});

final allBillsProvider = FutureProvider<List<Bill>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllBills();
});
