import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

final databaseProvider = Provider<BillMedDatabase>((ref) {
  final db = BillMedDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Live list of every bill with its paid total. Single source of truth —
/// screens derive/filter/aggregate from this instead of hand-invalidating.
final billsWithPaidProvider = StreamProvider.autoDispose<List<BillPaid>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllBillsWithPaid();
});

final distributorListStreamProvider =
    StreamProvider.autoDispose<List<Distributor>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllDistributors();
});

final paymentsStreamProvider =
    StreamProvider.autoDispose.family<List<Payment>, int>((ref, billId) {
  final db = ref.watch(databaseProvider);
  return db.watchPaymentsByBill(billId);
});

final billByIdProvider =
    FutureProvider.autoDispose.family<BillPaid?, int>((ref, billId) async {
  ref.watch(paymentsStreamProvider(billId));
  ref.watch(billsWithPaidProvider);
  final db = ref.watch(databaseProvider);
  return db.getBillWithPaid(billId);
});
