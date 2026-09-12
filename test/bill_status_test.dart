import 'package:flutter_test/flutter_test.dart';
import 'package:billmed/models/bill_status.dart';

void main() {
  group('computeBillStatus', () {
    test('unpaid when nothing paid', () {
      expect(computeBillStatus(10000, 0), BillStatus.unpaid);
      expect(computeBillStatus(10000, -5), BillStatus.unpaid);
    });

    test('partial when paid less than amount', () {
      expect(computeBillStatus(10000, 1), BillStatus.partial);
      expect(computeBillStatus(10000, 9999), BillStatus.partial);
    });

    test('paid exactly at amount', () {
      expect(computeBillStatus(10000, 10000), BillStatus.paid);
    });

    test('overpaid beyond amount', () {
      expect(computeBillStatus(10000, 10001), BillStatus.overpaid);
    });

    test('labels are user-facing', () {
      expect(BillStatus.unpaid.label, 'Unpaid');
      expect(BillStatus.partial.label, 'Partial');
      expect(BillStatus.paid.label, 'Paid');
      expect(BillStatus.overpaid.label, 'Overpaid');
    });

    test('isSettled only for paid/overpaid', () {
      expect(BillStatus.unpaid.isSettled, isFalse);
      expect(BillStatus.partial.isSettled, isFalse);
      expect(BillStatus.paid.isSettled, isTrue);
      expect(BillStatus.overpaid.isSettled, isTrue);
    });
  });

  group('isBillOverdue', () {
    final now = DateTime(2026, 6, 15);

    test('overdue after 30 days when unsettled', () {
      expect(isBillOverdue(DateTime(2026, 5, 1), 10000, 0, now: now), isTrue);
      expect(
          isBillOverdue(DateTime(2026, 5, 10), 10000, 5000, now: now), isTrue);
    });

    test('not overdue within 30 days', () {
      expect(isBillOverdue(DateTime(2026, 5, 20), 10000, 0, now: now), isFalse);
    });

    test('settled bills are never overdue', () {
      expect(
          isBillOverdue(DateTime(2026, 1, 1), 10000, 10000, now: now), isFalse);
      expect(
          isBillOverdue(DateTime(2026, 1, 1), 10000, 12000, now: now), isFalse);
    });

    test('day boundary: exactly 30 days not overdue, 31 is', () {
      final bill = DateTime(2026, 5, 16);
      expect(
          isBillOverdue(bill, 10000, 0, now: DateTime(2026, 6, 15)), isFalse);
      expect(isBillOverdue(bill, 10000, 0, now: DateTime(2026, 6, 16)), isTrue);
    });
  });
}
