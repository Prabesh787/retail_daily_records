import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';

/// A wholesale bill, recorded as one lump sum.
///
/// There are deliberately no purchase line items, no product master and no
/// stock tracking. The shop buys from a wholesaler and writes down one amount:
///
///     Supplier    ABC Textile
///     Bill No     4521
///     Bill Date   2083-05-10 (BS)
///     Amount      Rs. 100,000
///
/// Modelling it as an itemised document would invent data nobody records. The
/// paper bill can be scanned and attached as evidence instead.
///
/// A purchase is never stamped with how much has been paid against it —
/// payments are separate rows, so partial, credit, cash-plus-cheque and
/// future-dated settlements are all expressible.
class Purchase extends SyncableModel {
  const Purchase({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.fiscalYearId,
    required this.supplierId,
    required this.billNo,
    required this.billDate,
    required this.amount,
    this.billDateBs,
    this.description,
    this.remarks,
    this.createdById,
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
    this.supplierName,
    this.paidTotal,
  });

  final String fiscalYearId;
  final String supplierId;

  /// Copied off the wholesaler's paper bill, so it is only unique per supplier
  /// per fiscal year — two suppliers may legitimately both issue a "4521".
  final String billNo;

  /// AD, as the epoch millis every query sorts and ranges on.
  final int billDate;

  /// The BS string written on the bill, kept for display and printing.
  final String? billDateBs;

  final String? description;
  final Money amount;
  final String? remarks;
  final String? createdById;

  /// Joined in for display; not a stored column.
  final String? supplierName;

  /// Derived from the payment rows against this bill. Null when not asked for.
  final Money? paidTotal;

  Money? get dueTotal => paidTotal == null ? null : amount - paidTotal!;

  bool get isFullyPaid => dueTotal?.isZero ?? false;

  String get billDateBsOrDerived =>
      billDateBs ?? NepaliDate.msToBs(billDate) ?? '';

  @override
  Map<String, dynamic> toMap() => {
        ...syncMap,
        'fiscal_year_id': fiscalYearId,
        'supplier_id': supplierId,
        'bill_no': billNo,
        'bill_date': billDate,
        'bill_date_bs': billDateBs,
        'description': description,
        'amount': amount.toColumn(),
        'remarks': remarks,
        'created_by': createdById,
      };

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'fiscalYearId': fiscalYearId,
        'supplierId': supplierId,
        'billNo': billNo,
        'billDate': NepaliDate.toIsoDate(NepaliDate.fromMs(billDate)),
        'billDateBs': billDateBs,
        'description': description,
        'amount': amount.toWire(),
        'remarks': remarks,
        'createdById': createdById,
        ...syncJson,
      };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
        id: SyncableModel.idOf(map),
        createdAt: SyncableModel.createdAtOf(map),
        updatedAt: SyncableModel.updatedAtOf(map),
        isDeleted: SyncableModel.isDeletedOf(map),
        syncStatus: SyncableModel.syncStatusOf(map),
        deviceId: SyncableModel.deviceIdOf(map),
        fiscalYearId: (map['fiscal_year_id'] as String?) ?? '',
        supplierId: (map['supplier_id'] as String?) ?? '',
        billNo: (map['bill_no'] as String?) ?? '',
        billDate: SyncableModel.toInt(map['bill_date']),
        billDateBs: map['bill_date_bs'] as String?,
        description: map['description'] as String?,
        amount: Money.fromColumn(map['amount']),
        remarks: map['remarks'] as String?,
        createdById: map['created_by'] as String?,
        supplierName: map['supplier_name'] as String?,
        paidTotal: map.containsKey('paid_total')
            ? Money.fromColumn(map['paid_total'])
            : null,
      );

  Purchase copyWith({
    String? fiscalYearId,
    String? supplierId,
    String? billNo,
    int? billDate,
    String? billDateBs,
    String? description,
    Money? amount,
    String? remarks,
    String? createdById,
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
    String? supplierName,
    Money? paidTotal,
  }) =>
      Purchase(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        fiscalYearId: fiscalYearId ?? this.fiscalYearId,
        supplierId: supplierId ?? this.supplierId,
        billNo: billNo ?? this.billNo,
        billDate: billDate ?? this.billDate,
        billDateBs: billDateBs ?? this.billDateBs,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        remarks: remarks ?? this.remarks,
        createdById: createdById ?? this.createdById,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        deviceId: deviceId ?? this.deviceId,
        supplierName: supplierName ?? this.supplierName,
        paidTotal: paidTotal ?? this.paidTotal,
      );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.purchase} (
      id             TEXT PRIMARY KEY,
      fiscal_year_id TEXT NOT NULL,
      supplier_id    TEXT NOT NULL,
      bill_no        TEXT NOT NULL,
      bill_date      INTEGER NOT NULL,
      bill_date_bs   TEXT,
      description    TEXT,
      amount         INTEGER NOT NULL DEFAULT 0,
      remarks        TEXT,
      created_by     TEXT,
      ${SyncColumns.definition}
    )
  ''';

  // No foreign keys to `fiscal_years` or `suppliers`, deliberately.
  //
  // Once sync is on, a pulled row can legitimately arrive before its parent:
  // another device created the supplier, or its page has not come down yet.
  // With the constraint on, that insert throws, the engine skips the row and
  // the cursor moves past it — and the bill is gone with nothing to say so.
  // Referential integrity is the server's job; here the constraint would trade
  // a self-correcting ordering problem for silent data loss.

  /// Mirrors `purchases_supplier_fy_bill_no_key` on the server, so a duplicate
  /// is refused on the device rather than surviving until a sync rejects it.
  /// Partial, because a voided bill should not reserve its number forever.
  static const String uniqueBillNoSql = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_supplier_fy_bill_no
      ON ${DbTables.purchase} (supplier_id, fiscal_year_id, bill_no)
      WHERE is_deleted = 0
  ''';
}
