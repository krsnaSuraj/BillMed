// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DistributorsTable extends Distributors
    with TableInfo<$DistributorsTable, Distributor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DistributorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyMeta =
      const VerificationMeta('company');
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
      'company', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, company, phone, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'distributors';
  @override
  VerificationContext validateIntegrity(Insertable<Distributor> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('company')) {
      context.handle(_companyMeta,
          company.isAcceptableOrUnknown(data['company']!, _companyMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Distributor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Distributor(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      company: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DistributorsTable createAlias(String alias) {
    return $DistributorsTable(attachedDatabase, alias);
  }
}

class Distributor extends DataClass implements Insertable<Distributor> {
  final int id;
  final String name;
  final String? company;
  final String? phone;
  final DateTime createdAt;
  const Distributor(
      {required this.id,
      required this.name,
      this.company,
      this.phone,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || company != null) {
      map['company'] = Variable<String>(company);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DistributorsCompanion toCompanion(bool nullToAbsent) {
    return DistributorsCompanion(
      id: Value(id),
      name: Value(name),
      company: company == null && nullToAbsent
          ? const Value.absent()
          : Value(company),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      createdAt: Value(createdAt),
    );
  }

  factory Distributor.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Distributor(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      company: serializer.fromJson<String?>(json['company']),
      phone: serializer.fromJson<String?>(json['phone']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'company': serializer.toJson<String?>(company),
      'phone': serializer.toJson<String?>(phone),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Distributor copyWith(
          {int? id,
          String? name,
          Value<String?> company = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          DateTime? createdAt}) =>
      Distributor(
        id: id ?? this.id,
        name: name ?? this.name,
        company: company.present ? company.value : this.company,
        phone: phone.present ? phone.value : this.phone,
        createdAt: createdAt ?? this.createdAt,
      );
  Distributor copyWithCompanion(DistributorsCompanion data) {
    return Distributor(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      company: data.company.present ? data.company.value : this.company,
      phone: data.phone.present ? data.phone.value : this.phone,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Distributor(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('company: $company, ')
          ..write('phone: $phone, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, company, phone, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Distributor &&
          other.id == this.id &&
          other.name == this.name &&
          other.company == this.company &&
          other.phone == this.phone &&
          other.createdAt == this.createdAt);
}

class DistributorsCompanion extends UpdateCompanion<Distributor> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> company;
  final Value<String?> phone;
  final Value<DateTime> createdAt;
  const DistributorsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.company = const Value.absent(),
    this.phone = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DistributorsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.company = const Value.absent(),
    this.phone = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Distributor> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? company,
    Expression<String>? phone,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (company != null) 'company': company,
      if (phone != null) 'phone': phone,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DistributorsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? company,
      Value<String?>? phone,
      Value<DateTime>? createdAt}) {
    return DistributorsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DistributorsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('company: $company, ')
          ..write('phone: $phone, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BillsTable extends Bills with TableInfo<$BillsTable, Bill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _distributorIdMeta =
      const VerificationMeta('distributorId');
  @override
  late final GeneratedColumn<int> distributorId = GeneratedColumn<int>(
      'distributor_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES distributors (id)'));
  static const VerificationMeta _billNumberMeta =
      const VerificationMeta('billNumber');
  @override
  late final GeneratedColumn<String> billNumber = GeneratedColumn<String>(
      'bill_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _billDateMeta =
      const VerificationMeta('billDate');
  @override
  late final GeneratedColumn<DateTime> billDate = GeneratedColumn<DateTime>(
      'bill_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, distributorId, billNumber, billDate, amount, notes, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bills';
  @override
  VerificationContext validateIntegrity(Insertable<Bill> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('distributor_id')) {
      context.handle(
          _distributorIdMeta,
          distributorId.isAcceptableOrUnknown(
              data['distributor_id']!, _distributorIdMeta));
    } else if (isInserting) {
      context.missing(_distributorIdMeta);
    }
    if (data.containsKey('bill_number')) {
      context.handle(
          _billNumberMeta,
          billNumber.isAcceptableOrUnknown(
              data['bill_number']!, _billNumberMeta));
    } else if (isInserting) {
      context.missing(_billNumberMeta);
    }
    if (data.containsKey('bill_date')) {
      context.handle(_billDateMeta,
          billDate.isAcceptableOrUnknown(data['bill_date']!, _billDateMeta));
    } else if (isInserting) {
      context.missing(_billDateMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bill(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      distributorId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}distributor_id'])!,
      billNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bill_number'])!,
      billDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}bill_date'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BillsTable createAlias(String alias) {
    return $BillsTable(attachedDatabase, alias);
  }
}

class Bill extends DataClass implements Insertable<Bill> {
  final int id;
  final int distributorId;
  final String billNumber;
  final DateTime billDate;
  final double amount;
  final String? notes;
  final DateTime createdAt;
  const Bill(
      {required this.id,
      required this.distributorId,
      required this.billNumber,
      required this.billDate,
      required this.amount,
      this.notes,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['distributor_id'] = Variable<int>(distributorId);
    map['bill_number'] = Variable<String>(billNumber);
    map['bill_date'] = Variable<DateTime>(billDate);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BillsCompanion toCompanion(bool nullToAbsent) {
    return BillsCompanion(
      id: Value(id),
      distributorId: Value(distributorId),
      billNumber: Value(billNumber),
      billDate: Value(billDate),
      amount: Value(amount),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Bill.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bill(
      id: serializer.fromJson<int>(json['id']),
      distributorId: serializer.fromJson<int>(json['distributorId']),
      billNumber: serializer.fromJson<String>(json['billNumber']),
      billDate: serializer.fromJson<DateTime>(json['billDate']),
      amount: serializer.fromJson<double>(json['amount']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'distributorId': serializer.toJson<int>(distributorId),
      'billNumber': serializer.toJson<String>(billNumber),
      'billDate': serializer.toJson<DateTime>(billDate),
      'amount': serializer.toJson<double>(amount),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bill copyWith(
          {int? id,
          int? distributorId,
          String? billNumber,
          DateTime? billDate,
          double? amount,
          Value<String?> notes = const Value.absent(),
          DateTime? createdAt}) =>
      Bill(
        id: id ?? this.id,
        distributorId: distributorId ?? this.distributorId,
        billNumber: billNumber ?? this.billNumber,
        billDate: billDate ?? this.billDate,
        amount: amount ?? this.amount,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
  Bill copyWithCompanion(BillsCompanion data) {
    return Bill(
      id: data.id.present ? data.id.value : this.id,
      distributorId: data.distributorId.present
          ? data.distributorId.value
          : this.distributorId,
      billNumber:
          data.billNumber.present ? data.billNumber.value : this.billNumber,
      billDate: data.billDate.present ? data.billDate.value : this.billDate,
      amount: data.amount.present ? data.amount.value : this.amount,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bill(')
          ..write('id: $id, ')
          ..write('distributorId: $distributorId, ')
          ..write('billNumber: $billNumber, ')
          ..write('billDate: $billDate, ')
          ..write('amount: $amount, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, distributorId, billNumber, billDate, amount, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bill &&
          other.id == this.id &&
          other.distributorId == this.distributorId &&
          other.billNumber == this.billNumber &&
          other.billDate == this.billDate &&
          other.amount == this.amount &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class BillsCompanion extends UpdateCompanion<Bill> {
  final Value<int> id;
  final Value<int> distributorId;
  final Value<String> billNumber;
  final Value<DateTime> billDate;
  final Value<double> amount;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const BillsCompanion({
    this.id = const Value.absent(),
    this.distributorId = const Value.absent(),
    this.billNumber = const Value.absent(),
    this.billDate = const Value.absent(),
    this.amount = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BillsCompanion.insert({
    this.id = const Value.absent(),
    required int distributorId,
    required String billNumber,
    required DateTime billDate,
    required double amount,
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : distributorId = Value(distributorId),
        billNumber = Value(billNumber),
        billDate = Value(billDate),
        amount = Value(amount);
  static Insertable<Bill> custom({
    Expression<int>? id,
    Expression<int>? distributorId,
    Expression<String>? billNumber,
    Expression<DateTime>? billDate,
    Expression<double>? amount,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (distributorId != null) 'distributor_id': distributorId,
      if (billNumber != null) 'bill_number': billNumber,
      if (billDate != null) 'bill_date': billDate,
      if (amount != null) 'amount': amount,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BillsCompanion copyWith(
      {Value<int>? id,
      Value<int>? distributorId,
      Value<String>? billNumber,
      Value<DateTime>? billDate,
      Value<double>? amount,
      Value<String?>? notes,
      Value<DateTime>? createdAt}) {
    return BillsCompanion(
      id: id ?? this.id,
      distributorId: distributorId ?? this.distributorId,
      billNumber: billNumber ?? this.billNumber,
      billDate: billDate ?? this.billDate,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (distributorId.present) {
      map['distributor_id'] = Variable<int>(distributorId.value);
    }
    if (billNumber.present) {
      map['bill_number'] = Variable<String>(billNumber.value);
    }
    if (billDate.present) {
      map['bill_date'] = Variable<DateTime>(billDate.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillsCompanion(')
          ..write('id: $id, ')
          ..write('distributorId: $distributorId, ')
          ..write('billNumber: $billNumber, ')
          ..write('billDate: $billDate, ')
          ..write('amount: $amount, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments with TableInfo<$PaymentsTable, Payment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  @override
  late final GeneratedColumn<int> billId = GeneratedColumn<int>(
      'bill_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES bills (id)'));
  static const VerificationMeta _paymentDateMeta =
      const VerificationMeta('paymentDate');
  @override
  late final GeneratedColumn<DateTime> paymentDate = GeneratedColumn<DateTime>(
      'payment_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _referenceNoMeta =
      const VerificationMeta('referenceNo');
  @override
  late final GeneratedColumn<String> referenceNo = GeneratedColumn<String>(
      'reference_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, billId, paymentDate, amount, mode, referenceNo, notes, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(Insertable<Payment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bill_id')) {
      context.handle(_billIdMeta,
          billId.isAcceptableOrUnknown(data['bill_id']!, _billIdMeta));
    } else if (isInserting) {
      context.missing(_billIdMeta);
    }
    if (data.containsKey('payment_date')) {
      context.handle(
          _paymentDateMeta,
          paymentDate.isAcceptableOrUnknown(
              data['payment_date']!, _paymentDateMeta));
    } else if (isInserting) {
      context.missing(_paymentDateMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('reference_no')) {
      context.handle(
          _referenceNoMeta,
          referenceNo.isAcceptableOrUnknown(
              data['reference_no']!, _referenceNoMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Payment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      billId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bill_id'])!,
      paymentDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}payment_date'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      referenceNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference_no']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }
}

class Payment extends DataClass implements Insertable<Payment> {
  final int id;
  final int billId;
  final DateTime paymentDate;
  final double amount;
  final String mode;
  final String? referenceNo;
  final String? notes;
  final DateTime createdAt;
  const Payment(
      {required this.id,
      required this.billId,
      required this.paymentDate,
      required this.amount,
      required this.mode,
      this.referenceNo,
      this.notes,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bill_id'] = Variable<int>(billId);
    map['payment_date'] = Variable<DateTime>(paymentDate);
    map['amount'] = Variable<double>(amount);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || referenceNo != null) {
      map['reference_no'] = Variable<String>(referenceNo);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      billId: Value(billId),
      paymentDate: Value(paymentDate),
      amount: Value(amount),
      mode: Value(mode),
      referenceNo: referenceNo == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceNo),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Payment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payment(
      id: serializer.fromJson<int>(json['id']),
      billId: serializer.fromJson<int>(json['billId']),
      paymentDate: serializer.fromJson<DateTime>(json['paymentDate']),
      amount: serializer.fromJson<double>(json['amount']),
      mode: serializer.fromJson<String>(json['mode']),
      referenceNo: serializer.fromJson<String?>(json['referenceNo']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'billId': serializer.toJson<int>(billId),
      'paymentDate': serializer.toJson<DateTime>(paymentDate),
      'amount': serializer.toJson<double>(amount),
      'mode': serializer.toJson<String>(mode),
      'referenceNo': serializer.toJson<String?>(referenceNo),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Payment copyWith(
          {int? id,
          int? billId,
          DateTime? paymentDate,
          double? amount,
          String? mode,
          Value<String?> referenceNo = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? createdAt}) =>
      Payment(
        id: id ?? this.id,
        billId: billId ?? this.billId,
        paymentDate: paymentDate ?? this.paymentDate,
        amount: amount ?? this.amount,
        mode: mode ?? this.mode,
        referenceNo: referenceNo.present ? referenceNo.value : this.referenceNo,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
  Payment copyWithCompanion(PaymentsCompanion data) {
    return Payment(
      id: data.id.present ? data.id.value : this.id,
      billId: data.billId.present ? data.billId.value : this.billId,
      paymentDate:
          data.paymentDate.present ? data.paymentDate.value : this.paymentDate,
      amount: data.amount.present ? data.amount.value : this.amount,
      mode: data.mode.present ? data.mode.value : this.mode,
      referenceNo:
          data.referenceNo.present ? data.referenceNo.value : this.referenceNo,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payment(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('paymentDate: $paymentDate, ')
          ..write('amount: $amount, ')
          ..write('mode: $mode, ')
          ..write('referenceNo: $referenceNo, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, billId, paymentDate, amount, mode, referenceNo, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payment &&
          other.id == this.id &&
          other.billId == this.billId &&
          other.paymentDate == this.paymentDate &&
          other.amount == this.amount &&
          other.mode == this.mode &&
          other.referenceNo == this.referenceNo &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class PaymentsCompanion extends UpdateCompanion<Payment> {
  final Value<int> id;
  final Value<int> billId;
  final Value<DateTime> paymentDate;
  final Value<double> amount;
  final Value<String> mode;
  final Value<String?> referenceNo;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.billId = const Value.absent(),
    this.paymentDate = const Value.absent(),
    this.amount = const Value.absent(),
    this.mode = const Value.absent(),
    this.referenceNo = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PaymentsCompanion.insert({
    this.id = const Value.absent(),
    required int billId,
    required DateTime paymentDate,
    required double amount,
    required String mode,
    this.referenceNo = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : billId = Value(billId),
        paymentDate = Value(paymentDate),
        amount = Value(amount),
        mode = Value(mode);
  static Insertable<Payment> custom({
    Expression<int>? id,
    Expression<int>? billId,
    Expression<DateTime>? paymentDate,
    Expression<double>? amount,
    Expression<String>? mode,
    Expression<String>? referenceNo,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billId != null) 'bill_id': billId,
      if (paymentDate != null) 'payment_date': paymentDate,
      if (amount != null) 'amount': amount,
      if (mode != null) 'mode': mode,
      if (referenceNo != null) 'reference_no': referenceNo,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PaymentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? billId,
      Value<DateTime>? paymentDate,
      Value<double>? amount,
      Value<String>? mode,
      Value<String?>? referenceNo,
      Value<String?>? notes,
      Value<DateTime>? createdAt}) {
    return PaymentsCompanion(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      referenceNo: referenceNo ?? this.referenceNo,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (billId.present) {
      map['bill_id'] = Variable<int>(billId.value);
    }
    if (paymentDate.present) {
      map['payment_date'] = Variable<DateTime>(paymentDate.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (referenceNo.present) {
      map['reference_no'] = Variable<String>(referenceNo.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('paymentDate: $paymentDate, ')
          ..write('amount: $amount, ')
          ..write('mode: $mode, ')
          ..write('referenceNo: $referenceNo, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$BillMedDatabase extends GeneratedDatabase {
  _$BillMedDatabase(QueryExecutor e) : super(e);
  $BillMedDatabaseManager get managers => $BillMedDatabaseManager(this);
  late final $DistributorsTable distributors = $DistributorsTable(this);
  late final $BillsTable bills = $BillsTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [distributors, bills, payments];
}

typedef $$DistributorsTableCreateCompanionBuilder = DistributorsCompanion
    Function({
  Value<int> id,
  required String name,
  Value<String?> company,
  Value<String?> phone,
  Value<DateTime> createdAt,
});
typedef $$DistributorsTableUpdateCompanionBuilder = DistributorsCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String?> company,
  Value<String?> phone,
  Value<DateTime> createdAt,
});

final class $$DistributorsTableReferences
    extends BaseReferences<_$BillMedDatabase, $DistributorsTable, Distributor> {
  $$DistributorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BillsTable, List<Bill>> _billsRefsTable(
          _$BillMedDatabase db) =>
      MultiTypedResultKey.fromTable(db.bills,
          aliasName:
              $_aliasNameGenerator(db.distributors.id, db.bills.distributorId));

  $$BillsTableProcessedTableManager get billsRefs {
    final manager = $$BillsTableTableManager($_db, $_db.bills)
        .filter((f) => f.distributorId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_billsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$DistributorsTableFilterComposer
    extends Composer<_$BillMedDatabase, $DistributorsTable> {
  $$DistributorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get company => $composableBuilder(
      column: $table.company, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> billsRefs(
      Expression<bool> Function($$BillsTableFilterComposer f) f) {
    final $$BillsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bills,
        getReferencedColumn: (t) => t.distributorId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BillsTableFilterComposer(
              $db: $db,
              $table: $db.bills,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DistributorsTableOrderingComposer
    extends Composer<_$BillMedDatabase, $DistributorsTable> {
  $$DistributorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get company => $composableBuilder(
      column: $table.company, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DistributorsTableAnnotationComposer
    extends Composer<_$BillMedDatabase, $DistributorsTable> {
  $$DistributorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> billsRefs<T extends Object>(
      Expression<T> Function($$BillsTableAnnotationComposer a) f) {
    final $$BillsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bills,
        getReferencedColumn: (t) => t.distributorId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BillsTableAnnotationComposer(
              $db: $db,
              $table: $db.bills,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DistributorsTableTableManager extends RootTableManager<
    _$BillMedDatabase,
    $DistributorsTable,
    Distributor,
    $$DistributorsTableFilterComposer,
    $$DistributorsTableOrderingComposer,
    $$DistributorsTableAnnotationComposer,
    $$DistributorsTableCreateCompanionBuilder,
    $$DistributorsTableUpdateCompanionBuilder,
    (Distributor, $$DistributorsTableReferences),
    Distributor,
    PrefetchHooks Function({bool billsRefs})> {
  $$DistributorsTableTableManager(
      _$BillMedDatabase db, $DistributorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DistributorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DistributorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DistributorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> company = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              DistributorsCompanion(
            id: id,
            name: name,
            company: company,
            phone: phone,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> company = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              DistributorsCompanion.insert(
            id: id,
            name: name,
            company: company,
            phone: phone,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DistributorsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({billsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (billsRefs) db.bills],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (billsRefs)
                    await $_getPrefetchedData<Distributor, $DistributorsTable,
                            Bill>(
                        currentTable: table,
                        referencedTable:
                            $$DistributorsTableReferences._billsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$DistributorsTableReferences(db, table, p0)
                                .billsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.distributorId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$DistributorsTableProcessedTableManager = ProcessedTableManager<
    _$BillMedDatabase,
    $DistributorsTable,
    Distributor,
    $$DistributorsTableFilterComposer,
    $$DistributorsTableOrderingComposer,
    $$DistributorsTableAnnotationComposer,
    $$DistributorsTableCreateCompanionBuilder,
    $$DistributorsTableUpdateCompanionBuilder,
    (Distributor, $$DistributorsTableReferences),
    Distributor,
    PrefetchHooks Function({bool billsRefs})>;
typedef $$BillsTableCreateCompanionBuilder = BillsCompanion Function({
  Value<int> id,
  required int distributorId,
  required String billNumber,
  required DateTime billDate,
  required double amount,
  Value<String?> notes,
  Value<DateTime> createdAt,
});
typedef $$BillsTableUpdateCompanionBuilder = BillsCompanion Function({
  Value<int> id,
  Value<int> distributorId,
  Value<String> billNumber,
  Value<DateTime> billDate,
  Value<double> amount,
  Value<String?> notes,
  Value<DateTime> createdAt,
});

final class $$BillsTableReferences
    extends BaseReferences<_$BillMedDatabase, $BillsTable, Bill> {
  $$BillsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DistributorsTable _distributorIdTable(_$BillMedDatabase db) =>
      db.distributors.createAlias(
          $_aliasNameGenerator(db.bills.distributorId, db.distributors.id));

  $$DistributorsTableProcessedTableManager get distributorId {
    final $_column = $_itemColumn<int>('distributor_id')!;

    final manager = $$DistributorsTableTableManager($_db, $_db.distributors)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_distributorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$PaymentsTable, List<Payment>> _paymentsRefsTable(
          _$BillMedDatabase db) =>
      MultiTypedResultKey.fromTable(db.payments,
          aliasName: $_aliasNameGenerator(db.bills.id, db.payments.billId));

  $$PaymentsTableProcessedTableManager get paymentsRefs {
    final manager = $$PaymentsTableTableManager($_db, $_db.payments)
        .filter((f) => f.billId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BillsTableFilterComposer
    extends Composer<_$BillMedDatabase, $BillsTable> {
  $$BillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get billNumber => $composableBuilder(
      column: $table.billNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get billDate => $composableBuilder(
      column: $table.billDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$DistributorsTableFilterComposer get distributorId {
    final $$DistributorsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.distributorId,
        referencedTable: $db.distributors,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DistributorsTableFilterComposer(
              $db: $db,
              $table: $db.distributors,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> paymentsRefs(
      Expression<bool> Function($$PaymentsTableFilterComposer f) f) {
    final $$PaymentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.payments,
        getReferencedColumn: (t) => t.billId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PaymentsTableFilterComposer(
              $db: $db,
              $table: $db.payments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BillsTableOrderingComposer
    extends Composer<_$BillMedDatabase, $BillsTable> {
  $$BillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get billNumber => $composableBuilder(
      column: $table.billNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get billDate => $composableBuilder(
      column: $table.billDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$DistributorsTableOrderingComposer get distributorId {
    final $$DistributorsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.distributorId,
        referencedTable: $db.distributors,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DistributorsTableOrderingComposer(
              $db: $db,
              $table: $db.distributors,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BillsTableAnnotationComposer
    extends Composer<_$BillMedDatabase, $BillsTable> {
  $$BillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get billNumber => $composableBuilder(
      column: $table.billNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get billDate =>
      $composableBuilder(column: $table.billDate, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DistributorsTableAnnotationComposer get distributorId {
    final $$DistributorsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.distributorId,
        referencedTable: $db.distributors,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DistributorsTableAnnotationComposer(
              $db: $db,
              $table: $db.distributors,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> paymentsRefs<T extends Object>(
      Expression<T> Function($$PaymentsTableAnnotationComposer a) f) {
    final $$PaymentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.payments,
        getReferencedColumn: (t) => t.billId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PaymentsTableAnnotationComposer(
              $db: $db,
              $table: $db.payments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BillsTableTableManager extends RootTableManager<
    _$BillMedDatabase,
    $BillsTable,
    Bill,
    $$BillsTableFilterComposer,
    $$BillsTableOrderingComposer,
    $$BillsTableAnnotationComposer,
    $$BillsTableCreateCompanionBuilder,
    $$BillsTableUpdateCompanionBuilder,
    (Bill, $$BillsTableReferences),
    Bill,
    PrefetchHooks Function({bool distributorId, bool paymentsRefs})> {
  $$BillsTableTableManager(_$BillMedDatabase db, $BillsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> distributorId = const Value.absent(),
            Value<String> billNumber = const Value.absent(),
            Value<DateTime> billDate = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              BillsCompanion(
            id: id,
            distributorId: distributorId,
            billNumber: billNumber,
            billDate: billDate,
            amount: amount,
            notes: notes,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int distributorId,
            required String billNumber,
            required DateTime billDate,
            required double amount,
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              BillsCompanion.insert(
            id: id,
            distributorId: distributorId,
            billNumber: billNumber,
            billDate: billDate,
            amount: amount,
            notes: notes,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$BillsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {distributorId = false, paymentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (paymentsRefs) db.payments],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (distributorId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.distributorId,
                    referencedTable:
                        $$BillsTableReferences._distributorIdTable(db),
                    referencedColumn:
                        $$BillsTableReferences._distributorIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (paymentsRefs)
                    await $_getPrefetchedData<Bill, $BillsTable, Payment>(
                        currentTable: table,
                        referencedTable:
                            $$BillsTableReferences._paymentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BillsTableReferences(db, table, p0).paymentsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.billId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BillsTableProcessedTableManager = ProcessedTableManager<
    _$BillMedDatabase,
    $BillsTable,
    Bill,
    $$BillsTableFilterComposer,
    $$BillsTableOrderingComposer,
    $$BillsTableAnnotationComposer,
    $$BillsTableCreateCompanionBuilder,
    $$BillsTableUpdateCompanionBuilder,
    (Bill, $$BillsTableReferences),
    Bill,
    PrefetchHooks Function({bool distributorId, bool paymentsRefs})>;
typedef $$PaymentsTableCreateCompanionBuilder = PaymentsCompanion Function({
  Value<int> id,
  required int billId,
  required DateTime paymentDate,
  required double amount,
  required String mode,
  Value<String?> referenceNo,
  Value<String?> notes,
  Value<DateTime> createdAt,
});
typedef $$PaymentsTableUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<int> id,
  Value<int> billId,
  Value<DateTime> paymentDate,
  Value<double> amount,
  Value<String> mode,
  Value<String?> referenceNo,
  Value<String?> notes,
  Value<DateTime> createdAt,
});

final class $$PaymentsTableReferences
    extends BaseReferences<_$BillMedDatabase, $PaymentsTable, Payment> {
  $$PaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BillsTable _billIdTable(_$BillMedDatabase db) => db.bills
      .createAlias($_aliasNameGenerator(db.payments.billId, db.bills.id));

  $$BillsTableProcessedTableManager get billId {
    final $_column = $_itemColumn<int>('bill_id')!;

    final manager = $$BillsTableTableManager($_db, $_db.bills)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_billIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PaymentsTableFilterComposer
    extends Composer<_$BillMedDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get paymentDate => $composableBuilder(
      column: $table.paymentDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$BillsTableFilterComposer get billId {
    final $$BillsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.billId,
        referencedTable: $db.bills,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BillsTableFilterComposer(
              $db: $db,
              $table: $db.bills,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PaymentsTableOrderingComposer
    extends Composer<_$BillMedDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get paymentDate => $composableBuilder(
      column: $table.paymentDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$BillsTableOrderingComposer get billId {
    final $$BillsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.billId,
        referencedTable: $db.bills,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BillsTableOrderingComposer(
              $db: $db,
              $table: $db.bills,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PaymentsTableAnnotationComposer
    extends Composer<_$BillMedDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get paymentDate => $composableBuilder(
      column: $table.paymentDate, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BillsTableAnnotationComposer get billId {
    final $$BillsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.billId,
        referencedTable: $db.bills,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BillsTableAnnotationComposer(
              $db: $db,
              $table: $db.bills,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PaymentsTableTableManager extends RootTableManager<
    _$BillMedDatabase,
    $PaymentsTable,
    Payment,
    $$PaymentsTableFilterComposer,
    $$PaymentsTableOrderingComposer,
    $$PaymentsTableAnnotationComposer,
    $$PaymentsTableCreateCompanionBuilder,
    $$PaymentsTableUpdateCompanionBuilder,
    (Payment, $$PaymentsTableReferences),
    Payment,
    PrefetchHooks Function({bool billId})> {
  $$PaymentsTableTableManager(_$BillMedDatabase db, $PaymentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> billId = const Value.absent(),
            Value<DateTime> paymentDate = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<String?> referenceNo = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PaymentsCompanion(
            id: id,
            billId: billId,
            paymentDate: paymentDate,
            amount: amount,
            mode: mode,
            referenceNo: referenceNo,
            notes: notes,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int billId,
            required DateTime paymentDate,
            required double amount,
            required String mode,
            Value<String?> referenceNo = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PaymentsCompanion.insert(
            id: id,
            billId: billId,
            paymentDate: paymentDate,
            amount: amount,
            mode: mode,
            referenceNo: referenceNo,
            notes: notes,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PaymentsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({billId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (billId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.billId,
                    referencedTable: $$PaymentsTableReferences._billIdTable(db),
                    referencedColumn:
                        $$PaymentsTableReferences._billIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PaymentsTableProcessedTableManager = ProcessedTableManager<
    _$BillMedDatabase,
    $PaymentsTable,
    Payment,
    $$PaymentsTableFilterComposer,
    $$PaymentsTableOrderingComposer,
    $$PaymentsTableAnnotationComposer,
    $$PaymentsTableCreateCompanionBuilder,
    $$PaymentsTableUpdateCompanionBuilder,
    (Payment, $$PaymentsTableReferences),
    Payment,
    PrefetchHooks Function({bool billId})>;

class $BillMedDatabaseManager {
  final _$BillMedDatabase _db;
  $BillMedDatabaseManager(this._db);
  $$DistributorsTableTableManager get distributors =>
      $$DistributorsTableTableManager(_db, _db.distributors);
  $$BillsTableTableManager get bills =>
      $$BillsTableTableManager(_db, _db.bills);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
}
