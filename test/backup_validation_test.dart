// PIVOT (documented per task): BackupService.importBackup's RestoreResult
// probe logic cannot run in `flutter test` — it needs the UI file picker
// (FilePicker.platform.pickFiles: platform channel + human interaction),
// path_provider app-documents dir, and share_plus. Likewise CaReportConfig
// save/load needs SharedPreferences platform channels. None of that is
// deterministic without network/UI, so per the task this file instead covers
// the pure decision surface we CAN reach deterministically:
//   (a) money fuzz: 200 rapid paise round-trips + adversarial parser inputs
//   (b) summary_service edge cases for buildDashboardSummary.
import 'package:flutter_test/flutter_test.dart';

import 'package:billmed/database/database.dart';
import 'package:billmed/services/summary_service.dart';
import 'package:billmed/utils/money.dart';

Bill _bill(int id, int distId, int amountPaise, DateTime date) => Bill(
      id: id,
      distributorId: distId,
      billNumber: 'B$id',
      billDate: date,
      amountPaise: amountPaise,
      notes: null,
      createdAt: date,
    );

Distributor _dist(int id, String name) => Distributor(
      id: id,
      name: name,
      company: null,
      phone: null,
      createdAt: DateTime(2025),
    );

/// Boundary paise values from the task spec.
const _boundaries = [
  0,
  1,
  5,
  9,
  10,
  99,
  100,
  101,
  999,
  1000,
  9999,
  10000,
  99999,
  100000,
  9999999,
  123456789,
  99999999999,
];

void main() {
  group('money fuzz: paise round-trip', () {
    test('200 rapid round-trips across boundary values are exact', () {
      for (var i = 0; i < 200; i++) {
        final paise = _boundaries[i % _boundaries.length];
        final editable = paiseToEditableString(paise);
        final back = rupeesInputToPaise(editable);
        expect(back, paise,
            reason: 'round-trip #$i failed for paise=$paise ("$editable")');
      }
    });

    test('every boundary value round-trips exactly', () {
      for (final paise in _boundaries) {
        expect(rupeesInputToPaise(paiseToEditableString(paise)), paise,
            reason: 'boundary paise=$paise');
      }
    });

    test('editable strings have the documented shape', () {
      expect(paiseToEditableString(0), '0');
      expect(paiseToEditableString(1), '0.01');
      expect(paiseToEditableString(5), '0.05');
      expect(paiseToEditableString(100), '1');
      expect(paiseToEditableString(101), '1.01');
      expect(paiseToEditableString(100075), '1000.75');
    });
  });

  group('money fuzz: adversarial parser inputs', () {
    final cases = <String, int>{
      '1e3': 0, // scientific notation rejected
      '+5': 0, // explicit plus rejected
      '--5': 0,
      '5..5': 0,
      ',,,': 0, // commas are grouping only → malformed → rejected
      '₹100': 0, // currency symbols rejected
      r'$100': 0,
      '1,2,3': 0, // not a valid grouping: never read as ₹123
      '12,50': 0, // a decimal comma is not ₹1,250
      '0.001': 0, // 3 decimals rejected (no rounding path reached)
      '0.005': 0, // same: regex allows max 2 decimals
      '999999999999': 0, // 12 digits > 11-digit cap → rejected
      '0': 0,
      '0.00': 0,
      '  100.50  ': 10050, // surrounding whitespace trimmed
      '00.50': 50, // leading zeros allowed
      '': 0,
      '   ': 0,
      '.': 0,
      '1.': 0, // trailing dot rejected
      '.5': 0, // leading-digit required
      'abc': 0,
      '-5': 0,
    };
    test('each adversarial input maps to 0 or its expected value', () {
      cases.forEach((input, expected) {
        expect(rupeesInputToPaise(input), expected, reason: 'input "$input"');
      });
    });

    test('100-char numeric string is rejected', () {
      final long = List.filled(100, '9').join();
      expect(long.length, 100);
      expect(rupeesInputToPaise(long), 0);
    });

    test('11-digit rupees accepted, 12-digit rejected (cap boundary)', () {
      expect(rupeesInputToPaise('99999999999'), greaterThan(0));
      expect(rupeesInputToPaise('100000000000'), 0);
    });
  });

  group('summary_service edge cases', () {
    test('supplier with zero bills appears with zero balances', () {
      final lonely = _dist(1, 'Lonely');
      final s = buildDashboardSummary([lonely], const []);
      expect(s.totalDistributors, 1);
      expect(s.totalBills, 0);
      expect(s.balances, hasLength(1));
      expect(s.balances.first.billedPaise, 0);
      expect(s.balances.first.paidPaise, 0);
      expect(s.balances.first.pendingPaise, 0);
      expect(s.balances.first.hasPending, isFalse);
    });

    test('orphan bills have no balance row and no headline impact', () {
      // A bill whose supplier row is gone (impossible through the app: the
      // cascade deletes them — reachable only in a hand-made/foreign file).
      // The headline is the sum of the per-supplier dues, so an invisible bill
      // cannot inflate the number at the top of the dashboard; it stays visible
      // in the Bills tab, where it reads with a "?" supplier.
      final known = _dist(1, 'Known');
      final bills = [
        BillPaid(
            bill: _bill(1, 999, 50000, DateTime(2026, 5, 1)), paidPaise: 0),
      ];
      final s = buildDashboardSummary([known], bills);
      expect(s.totalBills, 1);
      expect(s.totalBilledPaise, 50000);
      expect(s.totalPendingPaise, 0,
          reason: 'the headline must equal the rows beneath it, and an orphan '
              'bill has no row');
      expect(s.balances, hasLength(1));
      expect(s.balances.first.billedPaise, 0);
      expect(s.balances.first.fullySettled, isTrue,
          reason: 'the listed supplier really has nothing to pay');
    });

    test('pending nets overpayment within a supplier, clamped at zero', () {
      final d = _dist(1, 'Netter');
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 10000, DateTime(2026, 5, 1)), paidPaise: 15000),
        BillPaid(bill: _bill(2, 1, 20000, DateTime(2026, 5, 2)), paidPaise: 0),
      ];
      final s = buildDashboardSummary([d], bills);
      // (10000-15000) + (20000-0) = 15000 → overpaid credit offsets dues.
      expect(s.balances.first.pendingPaise, 15000);
      expect(s.totalPendingPaise, 15000);
    });

    test('fully overpaid supplier clamps to zero, not negative', () {
      final d = _dist(1, 'Credit');
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 10000, DateTime(2026, 5, 1)), paidPaise: 15000),
      ];
      final s = buildDashboardSummary([d], bills);
      expect(s.balances.first.pendingPaise, 0);
      expect(s.totalPendingPaise, 0);
      // Total paid still records the raw overpayment (not clamped).
      expect(s.totalPaidPaise, 15000);
    });

    test('tie pending sorts alphabetically case-insensitively', () {
      final b = _dist(1, 'beta');
      final a = _dist(2, 'Alpha');
      final bills = [
        BillPaid(bill: _bill(1, 1, 5000, DateTime(2026, 5, 1)), paidPaise: 0),
        BillPaid(bill: _bill(2, 2, 5000, DateTime(2026, 5, 1)), paidPaise: 0),
      ];
      final s = buildDashboardSummary([b, a], bills);
      expect(s.balances.map((e) => e.distributor.name).toList(),
          ['Alpha', 'beta']);
    });

    test('overdue uses wall-clock now: 40d unpaid overdue, 5d not', () {
      final d = _dist(1, 'Ager');
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 1000, day.subtract(const Duration(days: 40))),
            paidPaise: 0),
        BillPaid(
            bill: _bill(2, 1, 2000, day.subtract(const Duration(days: 5))),
            paidPaise: 0),
      ];
      final s = buildDashboardSummary([d], bills);
      expect(s.overdueCount, 1);
      expect(s.balances.first.overdueCount, 1);
    });

    test('now parameter is respected (deterministic overdue)', () {
      // H4 fixed: buildDashboardSummary threads `now` into isOverdue.
      final d = _dist(1, 'Timey');
      final bills = [
        BillPaid(bill: _bill(1, 1, 1000, DateTime(2026, 5, 1)), paidPaise: 0),
      ];
      final past = buildDashboardSummary([d], bills, now: DateTime(2000));
      final future = buildDashboardSummary([d], bills, now: DateTime(2030));
      expect(past.overdueCount, 0,
          reason: 'bill is in the future relative to now=2000');
      expect(future.overdueCount, 1,
          reason: 'bill is ancient relative to now=2030');
      expect(future.balances.first.overdueCount, 1);
    });

    test('large paise sums stay exact (no float)', () {
      final d = _dist(1, 'Big');
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 99999999999, DateTime(2026, 5, 1)), paidPaise: 1),
        BillPaid(
            bill: _bill(2, 1, 123456789, DateTime(2026, 5, 2)),
            paidPaise: 123456789),
      ];
      final s = buildDashboardSummary([d], bills);
      expect(s.totalBilledPaise, 99999999999 + 123456789);
      expect(s.totalPaidPaise, 1 + 123456789);
      expect(s.totalPendingPaise, 99999999998);
      expect(s.balances.first.settledCount, 1);
    });
  });
}
