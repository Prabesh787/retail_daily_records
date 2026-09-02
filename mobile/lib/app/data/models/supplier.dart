import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';

/// A wholesale vendor the shop buys from.
///
/// Separate from `Customer` rather than sharing one "party" table: a supplier
/// carries an opening balance and a PAN and is the subject of the one
/// calculation this whole system exists for, while a customer is optional on a
/// sale and carries none of that.
class Supplier extends SyncableModel {
  const Supplier({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.pan,
    this.openingBalance = Money.zero,
    this.isActive = true,
    this.remarks,
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
    this.balance,
  });

  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? pan;

  /// What was owed on the day the shop started using the app. An input to the
  /// derived outstanding figure, never a running total.
  final Money openingBalance;

  final bool isActive;
  final String? remarks;

  /// Derived by the DAO's ledger query and joined in for display — never a
  /// stored column, here or on the server.
  ///
  /// Null means "not asked for", which is different from "zero": a list screen
  /// that did not run the ledger query should show nothing rather than claim
  /// the supplier is settled.
  final SupplierBalance? balance;

  @override
  Map<String, dynamic> toMap() => {
        ...syncMap,
        'name': name,
        'contact_person': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'pan': pan,
        'opening_balance': openingBalance.toColumn(),
        'is_active': isActive ? 1 : 0,
        'remarks': remarks,
      };

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'pan': pan,
        'openingBalance': openingBalance.toWire(),
        'isActive': isActive,
        'remarks': remarks,
        ...syncJson,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: SyncableModel.idOf(map),
        createdAt: SyncableModel.createdAtOf(map),
        updatedAt: SyncableModel.updatedAtOf(map),
        isDeleted: SyncableModel.isDeletedOf(map),
        syncStatus: SyncableModel.syncStatusOf(map),
        deviceId: SyncableModel.deviceIdOf(map),
        name: (map['name'] as String?) ?? '',
        contactPerson: map['contact_person'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        pan: map['pan'] as String?,
        openingBalance: Money.fromColumn(map['opening_balance']),
        isActive: (map['is_active'] as int?) != 0,
        remarks: map['remarks'] as String?,
        balance: SupplierBalance.fromJoinedRow(map),
      );

  Supplier copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? pan,
    Money? openingBalance,
    bool? isActive,
    String? remarks,
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
    SupplierBalance? balance,
  }) =>
      Supplier(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        name: name ?? this.name,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        pan: pan ?? this.pan,
        openingBalance: openingBalance ?? this.openingBalance,
        isActive: isActive ?? this.isActive,
        remarks: remarks ?? this.remarks,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        deviceId: deviceId ?? this.deviceId,
        balance: balance ?? this.balance,
      );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.supplier} (
      id              TEXT PRIMARY KEY,
      name            TEXT NOT NULL,
      contact_person  TEXT,
      phone           TEXT,
      email           TEXT,
      address         TEXT,
      pan             TEXT,
      opening_balance INTEGER NOT NULL DEFAULT 0,
      is_active       INTEGER NOT NULL DEFAULT 1,
      remarks         TEXT,
      ${SyncColumns.definition}
    )
  ''';
}

/// What the shop still owes one supplier, derived from the documents.
///
///     outstanding = opening balance + purchases − payments that are not cancelled
///
/// There is no `current_balance` column anywhere, here or on the server. A
/// stored total can drift away from the rows that produced it; this cannot.
///
/// A cheque handed over but not yet debited counts as paid — the shop has
/// parted with it — while still being reported separately as [uncleared],
/// because that money has not actually left the bank yet.
class SupplierBalance {
  const SupplierBalance({
    this.openingBalance = Money.zero,
    this.purchaseTotal = Money.zero,
    this.clearedTotal = Money.zero,
    this.uncleared = Money.zero,
    this.billCount = 0,
    this.paymentCount = 0,
  });

  final Money openingBalance;
  final Money purchaseTotal;

  /// Payments that have actually left the bank.
  final Money clearedTotal;

  /// Issued but not yet debited — counted as paid, reported separately.
  final Money uncleared;

  final int billCount;
  final int paymentCount;

  /// Cleared plus issued-but-uncleared. Cancelled payments settled nothing and
  /// are in neither.
  Money get paidTotal => clearedTotal + uncleared;

  Money get outstanding => openingBalance + purchaseTotal - paidTotal;

  bool get isSettled => outstanding.isZero;

  /// Reads the aggregate columns a ledger query joins onto a supplier row.
  ///
  /// Returns null when the query did not ask for them, so "not loaded" stays
  /// distinguishable from "settled".
  static SupplierBalance? fromJoinedRow(Map<String, dynamic> map) {
    if (!map.containsKey('purchase_total')) return null;
    return SupplierBalance(
      openingBalance: Money.fromColumn(map['opening_balance']),
      purchaseTotal: Money.fromColumn(map['purchase_total']),
      clearedTotal: Money.fromColumn(map['cleared_total']),
      uncleared: Money.fromColumn(map['uncleared_total']),
      billCount: SyncableModel.toInt(map['bill_count']),
      paymentCount: SyncableModel.toInt(map['payment_count']),
    );
  }
}
