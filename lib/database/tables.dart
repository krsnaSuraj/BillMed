import 'package:drift/drift.dart';

class Distributors extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get company => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get distributorId => integer().references(Distributors, #id)();
  TextColumn get billNumber => text()();
  DateTimeColumn get billDate => dateTime()();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get billId => integer().references(Bills, #id)();
  DateTimeColumn get paymentDate => dateTime()();
  RealColumn get amount => real()();
  TextColumn get mode => text()();
  TextColumn get referenceNo => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BankTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get txnDate => dateTime()();
  TextColumn get description => text()();
  RealColumn get debit => real().withDefault(const Constant(0))();
  RealColumn get credit => real().withDefault(const Constant(0))();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get sourceFile => text().nullable()();
  TextColumn get category => text().nullable()();
  BoolColumn get isReversal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
}
