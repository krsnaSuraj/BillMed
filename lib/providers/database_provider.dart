import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

final databaseProvider = Provider<BillMedDatabase>((ref) {
  return BillMedDatabase();
});

final distributorListProvider = FutureProvider<List<Distributor>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllDistributors();
});
