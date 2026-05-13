import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';

class ExportService {
  static Future<void> exportToCsv(BillMedDatabase db, {required String type}) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    switch (type) {
      case 'distributors':
        await _exportDistributors(db, dir, ts);
        break;
      case 'bills':
        await _exportBills(db, dir, ts);
        break;
      case 'payments':
        await _exportPayments(db, dir, ts);
        break;
      case 'all':
        await _exportDistributors(db, dir, ts);
        await _exportBills(db, dir, ts);
        await _exportPayments(db, dir, ts);
        break;
    }
  }

  static Future<void> _exportDistributors(BillMedDatabase db, Directory dir, String ts) async {
    final data = await db.getAllDistributors();
    final rows = <List<String>>[
      ['ID', 'Name', 'Company', 'Phone', 'Created At'],
      for (final d in data)
        [d.id.toString(), d.name, d.company ?? '', d.phone ?? '', d.createdAt.toIso8601String()],
    ];
    _writeAndShare(dir, 'BillMed_Distributors_$ts.csv', rows);
  }

  static Future<void> _exportBills(BillMedDatabase db, Directory dir, String ts) async {
    final data = await db.getAllBills();
    final dists = await db.getAllDistributors();
    final distMap = {for (final d in dists) d.id: d.name};
    final rows = <List<String>>[
      ['ID', 'Distributor', 'Bill Number', 'Bill Date', 'Amount', 'Notes', 'Created At'],
      for (final b in data)
        [
          b.id.toString(),
          distMap[b.distributorId] ?? 'Unknown',
          b.billNumber,
          '${b.billDate.year}-${b.billDate.month.toString().padLeft(2, '0')}-${b.billDate.day.toString().padLeft(2, '0')}',
          b.amount.toStringAsFixed(2),
          b.notes ?? '',
          b.createdAt.toIso8601String(),
        ],
    ];
    _writeAndShare(dir, 'BillMed_Bills_$ts.csv', rows);
  }

  static Future<void> _exportPayments(BillMedDatabase db, Directory dir, String ts) async {
    final allBills = await db.getAllBills();
    final allPayments = <Payment>[];
    for (final bill in allBills) {
      allPayments.addAll(await db.getPaymentsByBill(bill.id));
    }
    final rows = <List<String>>[
      ['ID', 'Bill ID', 'Date', 'Amount', 'Mode', 'Reference', 'Notes', 'Created At'],
      for (final p in allPayments)
        [
          p.id.toString(),
          p.billId.toString(),
          '${p.paymentDate.year}-${p.paymentDate.month.toString().padLeft(2, '0')}-${p.paymentDate.day.toString().padLeft(2, '0')}',
          p.amount.toStringAsFixed(2),
          p.mode,
          p.referenceNo ?? '',
          p.notes ?? '',
          p.createdAt.toIso8601String(),
        ],
    ];
    _writeAndShare(dir, 'BillMed_Payments_$ts.csv', rows);
  }

  static Future<void> _writeAndShare(Directory dir, String filename, List<List<String>> rows) async {
    final csv = const ListToCsvConverter().convert(rows);
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }
}
