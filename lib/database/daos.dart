import 'database.dart';

class DashboardSummary {
  final int totalDistributors;
  final int totalBills;
  final double totalAmount;
  final double totalPaid;
  final double totalPending;
  final List<DistributorBalance> distributorBalances;

  DashboardSummary({
    required this.totalDistributors,
    required this.totalBills,
    required this.totalAmount,
    required this.totalPaid,
    required this.totalPending,
    required this.distributorBalances,
  });
}

class DistributorBalance {
  final Distributor distributor;
  final double billedAmount;
  final double paidAmount;
  final double pendingAmount;
  final int billCount;
  final int paidBillCount;

  DistributorBalance({
    required this.distributor,
    required this.billedAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.billCount,
    required this.paidBillCount,
  });
}

class BillWithStatus {
  final Bill bill;
  final double paidAmount;
  final double remainingAmount;
  final String status;

  BillWithStatus({
    required this.bill,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
  });
}

class BillMedDao {
  final BillMedDatabase db;

  BillMedDao(this.db);

  Future<DashboardSummary> getDashboardSummary() async {
    final distributors = await db.getAllDistributors();
    final allBills = await db.getAllBills();

    if (allBills.isEmpty) {
      return DashboardSummary(
        totalDistributors: distributors.length,
        totalBills: 0,
        totalAmount: 0,
        totalPaid: 0,
        totalPending: 0,
        distributorBalances: distributors.map((d) {
          return DistributorBalance(
            distributor: d,
            billedAmount: 0,
            paidAmount: 0,
            pendingAmount: 0,
            billCount: 0,
            paidBillCount: 0,
          );
        }).toList(),
      );
    }

    final billIds = allBills.map((b) => b.id).toList();
    final paidMap = await db.getTotalPaidForBills(billIds);

    double totalAmount = 0;
    double totalPaid = 0;
    final distMap = <int, List<Bill>>{};
    for (final b in allBills) {
      totalAmount += b.amount;
      totalPaid += paidMap[b.id] ?? 0.0;
      distMap.putIfAbsent(b.distributorId, () => []).add(b);
    }

    final balances = <DistributorBalance>[];
    for (final d in distributors) {
      final ddBills = distMap[d.id] ?? [];
      double billed = 0;
      double paid = 0;
      int count = 0;
      int paidCount = 0;
      for (final b in ddBills) {
        billed += b.amount;
        final bp = paidMap[b.id] ?? 0.0;
        paid += bp;
        count++;
        if (bp >= b.amount) paidCount++;
      }
      balances.add(DistributorBalance(
        distributor: d,
        billedAmount: billed,
        paidAmount: paid,
        pendingAmount: billed - paid,
        billCount: count,
        paidBillCount: paidCount,
      ));
    }

    return DashboardSummary(
      totalDistributors: distributors.length,
      totalBills: allBills.length,
      totalAmount: totalAmount,
      totalPaid: totalPaid,
      totalPending: totalAmount - totalPaid,
      distributorBalances: balances,
    );
  }

  Future<BillWithStatus> getBillWithStatus(Bill bill) async {
    final paid = await db.getTotalPaidForBill(bill.id);
    final remaining = bill.amount - paid;
    String status;
    if (paid <= 0) {
      status = 'Unpaid';
    } else if (paid < bill.amount) {
      status = 'Partial';
    } else {
      status = 'Paid';
    }
    return BillWithStatus(
      bill: bill,
      paidAmount: paid,
      remainingAmount: remaining > 0 ? remaining : 0,
      status: status,
    );
  }

  Future<String> getBillStatus(Bill bill) async {
    final paid = await db.getTotalPaidForBill(bill.id);
    if (paid <= 0) return 'Unpaid';
    if (paid < bill.amount) return 'Partial';
    return 'Paid';
  }
}
