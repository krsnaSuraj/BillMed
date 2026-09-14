import '../database/database.dart';
import '../models/bill_status.dart';

/// Bill scopes on the supplier detail page. They mirror the
/// Billed / Paid / Pending tiles, so a tapped tile always lands on exactly
/// the bills behind that number.
///
/// - `all`     → every bill of the supplier (the Billed tile)
/// - `pending` → anything still owed: Unpaid **and** Partial (the Pending tile)
/// - `paid`    → bills with money paid against them, Partially paid included:
///   the set whose `Paid` lines add up to the Paid tile. Settled-only
///   contradicted the tile — a single ₹1,000 bill holding a ₹400 payment read
///   "Paid ₹400" beside a "Paid (0)" chip.
/// - `overdue` → unsettled and older than [overdueDays]
enum SupplierBillFilter { all, pending, paid, overdue }

extension SupplierBillFilterX on SupplierBillFilter {
  String get label => switch (this) {
        SupplierBillFilter.all => 'All',
        SupplierBillFilter.pending => 'Pending',
        SupplierBillFilter.paid => 'Paid',
        SupplierBillFilter.overdue => 'Overdue',
      };

  /// Honest empty-state title for a scope that has no rows.
  String get emptyTitle => switch (this) {
        SupplierBillFilter.all => 'No bills for this supplier yet',
        SupplierBillFilter.pending => 'No pending bills for this supplier',
        SupplierBillFilter.paid => 'No paid bills for this supplier yet',
        SupplierBillFilter.overdue => 'No overdue bills for this supplier',
      };

  bool matches(BillPaid bp) => switch (this) {
        SupplierBillFilter.all => true,
        SupplierBillFilter.pending => !bp.status.isSettled,
        // Any payment at all: these are the bills whose `Paid ₹` lines sum to
        // the Paid tile above the list.
        SupplierBillFilter.paid => bp.paidPaise > 0,
        SupplierBillFilter.overdue => bp.isOverdue,
      };
}

/// Live counts per scope, used for the chip labels. `all` is the list length
/// so an empty supplier still reports 0 instead of throwing.
Map<SupplierBillFilter, int> supplierBillCounts(List<BillPaid> bills) => {
      for (final f in SupplierBillFilter.values)
        f: f == SupplierBillFilter.all
            ? bills.length
            : bills.where(f.matches).length,
    };

/// Filtered copy — never the caller's list, so screens can hold both.
List<BillPaid> applySupplierBillFilter(
  List<BillPaid> bills,
  SupplierBillFilter filter,
) =>
    filter == SupplierBillFilter.all
        ? List<BillPaid>.of(bills)
        : bills.where(filter.matches).toList();

/// Date DESC with an id DESC tiebreak, so same-day bills never flip order
/// across rebuilds (Dart's sort is not stable).
List<BillPaid> sortSupplierBills(List<BillPaid> bills) => [...bills]..sort(
    (a, b) {
      final byDate = b.bill.billDate.compareTo(a.bill.billDate);
      return byDate != 0 ? byDate : b.bill.id.compareTo(a.bill.id);
    },
  );
