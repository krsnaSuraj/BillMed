enum BillStatus { unpaid, partial, paid, overpaid }

extension BillStatusX on BillStatus {
  String get label => switch (this) {
        BillStatus.unpaid => 'Unpaid',
        BillStatus.partial => 'Partial',
        BillStatus.paid => 'Paid',
        BillStatus.overpaid => 'Overpaid',
      };
  bool get isSettled => this == BillStatus.paid || this == BillStatus.overpaid;
}

BillStatus computeBillStatus(int amountPaise, int paidPaise) {
  if (paidPaise <= 0) return BillStatus.unpaid;
  if (paidPaise < amountPaise) return BillStatus.partial;
  if (paidPaise == amountPaise) return BillStatus.paid;
  return BillStatus.overpaid;
}

const int overdueDays = 30;

bool isBillOverdue(DateTime billDate, int amountPaise, int paidPaise,
    {DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  final DateTime todayDate = DateTime(today.year, today.month, today.day);
  final DateTime billDay =
      DateTime(billDate.year, billDate.month, billDate.day);
  final int ageDays = todayDate.difference(billDay).inDays;
  return ageDays > overdueDays &&
      !computeBillStatus(amountPaise, paidPaise).isSettled;
}
