import 'package:drift/drift.dart';

class Distributors extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get company => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_bills_distributor', columns: {#distributorId})
@TableIndex(name: 'idx_bills_bill_date', columns: {#billDate})
class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get distributorId => integer().references(Distributors, #id)();
  TextColumn get billNumber => text()();
  DateTimeColumn get billDate => dateTime()();
  IntColumn get amountPaise => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_payments_bill', columns: {#billId})
@TableIndex(name: 'idx_payments_payment_date', columns: {#paymentDate})
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get billId => integer().references(Bills, #id)();
  DateTimeColumn get paymentDate => dateTime()();
  IntColumn get amountPaise => integer()();
  TextColumn get mode => text()();
  TextColumn get referenceNo => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
