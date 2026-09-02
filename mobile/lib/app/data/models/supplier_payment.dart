import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/payment_status.dart';
import '../enums/supplier_payment_mode.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';

/// Money the shop paid a supplier.
///
/// Stored separately from the purchase it settles — never as a `paid_amount`
/// column — so that partial, credit, cash-plus-cheque and future-dated-cheque
/// settlements are all expressible:
///
///     Purchase              Rs. 100,000
///       Payment  CASH       Rs.  20,000   CLEARED
///       Payment  CHEQUE     Rs.  30,000   ISSUED, cheque date 2083-05-25
///       ----------------------------------------------------------------
///       Open credit         Rs.  50,000
///
/// [purchaseId] is optional: a payment may settle one specific bill, several
/// older ones, or just the supplier's general outstanding balance.
class SupplierPayment extends SyncableModel {
  const SupplierPayment({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.fiscalYearId,
    required this.supplierId,
    required this.paymentDate,
    required this.paymentMode,
    required this.amount,
    this.purchaseId,
    this.voucherNo,
    this.paymentDateBs,
    this.chequeNo,
    this.chequeDate,
    this.chequeDateBs,
    this.referenceNo,
    this.clearedDate,
    this.status = PaymentStatus.cleared,
    this.description,
    this.remarks,
    this.createdById,
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
    this.supplierName,
    this.purchaseBillNo,
  });

  final String fiscalYearId;
  final String supplierId;
  final String? purchaseId;

  /// Unique per fiscal year; voucher numbers restart each year.
  final String? voucherNo;

  /// The day the payment was made or the cheque was handed over — not the day
  /// it clears.
  final int paymentDate;
  final String? paymentDateBs;

  final SupplierPaymentMode paymentMode;
  final Money amount;

  /// Present only when [paymentMode] is cheque.
  final String? chequeNo;
  final int? chequeDate;
  final String? chequeDateBs;

  /// Bank or wallet reference, for transfers.
  final String? referenceNo;

  /// Null while the status is `ISSUED`. Set when the money actually leaves.
  final int? clearedDate;

  final PaymentStatus status;
  final String? description;
  final String? remarks;
  final String? createdById;

  /// Joined in for display; not stored columns.
  final String? supplierName;
  final String? purchaseBillNo;

  /// What this payment contributes to the supplier's derived balance. A
  /// cancelled payment settled nothing.
  Money get recognisedAmount => status.reducesLiability ? amount : Money.zero;

  /// Handed over but not yet debited — still counted as paid, still reported
  /// separately because the money has not left the bank.
  Money get unclearedAmount => status.isUncleared ? amount : Money.zero;

  /// The date the money has to be available on, which is what the cheque
  /// register sorts by — the date written on the cheque, not the day it was
  /// handed over.
  int get dueDate => chequeDate ?? paymentDate;

  bool get isChequeAwaitingClearance =>
      paymentMode.isCheque && status == PaymentStatus.issued;

  @override
  Map<String, dynamic> toMap() => {
        ...syncMap,
        'fiscal_year_id': fiscalYearId,
        'supplier_id': supplierId,
        'purchase_id': purchaseId,
        'voucher_no': voucherNo,
        'payment_date': paymentDate,
        'payment_date_bs': paymentDateBs,
        'payment_mode': paymentMode.value,
        'amount': amount.toColumn(),
        'cheque_no': chequeNo,
        'cheque_date': chequeDate,
        'cheque_date_bs': chequeDateBs,
        'reference_no': referenceNo,
        'cleared_date': clearedDate,
        'status': status.value,
        'description': description,
        'remarks': remarks,
        'created_by': createdById,
      };

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'fiscalYearId': fiscalYearId,
        'supplierId': supplierId,
        'purchaseId': purchaseId,
        'voucherNo': voucherNo,
        'paymentDate': _iso(paymentDate),
        'paymentDateBs': paymentDateBs,
        'paymentMode': paymentMode.value,
        'amount': amount.toWire(),
        'chequeNo': chequeNo,
        'chequeDate': _isoOrNull(chequeDate),
        'chequeDateBs': chequeDateBs,
        'referenceNo': referenceNo,
        'clearedDate': _isoOrNull(clearedDate),
        'status': status.value,
        'description': description,
        'remarks': remarks,
        'createdById': createdById,
        ...syncJson,
      };

  static String _iso(int ms) => NepaliDate.toIsoDate(NepaliDate.fromMs(ms));
  static String? _isoOrNull(int? ms) => ms == null ? null : _iso(ms);

  factory SupplierPayment.fromMap(Map<String, dynamic> map) => SupplierPayment(
        id: SyncableModel.idOf(map),
        createdAt: SyncableModel.createdAtOf(map),
        updatedAt: SyncableModel.updatedAtOf(map),
        isDeleted: SyncableModel.isDeletedOf(map),
        syncStatus: SyncableModel.syncStatusOf(map),
        deviceId: SyncableModel.deviceIdOf(map),
        fiscalYearId: (map['fiscal_year_id'] as String?) ?? '',
        supplierId: (map['supplier_id'] as String?) ?? '',
        purchaseId: map['purchase_id'] as String?,
        voucherNo: map['voucher_no'] as String?,
        paymentDate: SyncableModel.toInt(map['payment_date']),
        paymentDateBs: map['payment_date_bs'] as String?,
        paymentMode:
            SupplierPaymentMode.fromValue(map['payment_mode'] as String?),
        amount: Money.fromColumn(map['amount']),
        chequeNo: map['cheque_no'] as String?,
        chequeDate: map['cheque_date'] as int?,
        chequeDateBs: map['cheque_date_bs'] as String?,
        referenceNo: map['reference_no'] as String?,
        clearedDate: map['cleared_date'] as int?,
        status: PaymentStatus.fromValue(map['status'] as String?),
        description: map['description'] as String?,
        remarks: map['remarks'] as String?,
        createdById: map['created_by'] as String?,
        supplierName: map['supplier_name'] as String?,
        purchaseBillNo: map['purchase_bill_no'] as String?,
      );

  SupplierPayment copyWith({
    String? fiscalYearId,
    String? supplierId,
    String? purchaseId,
    String? voucherNo,
    int? paymentDate,
    String? paymentDateBs,
    SupplierPaymentMode? paymentMode,
    Money? amount,
    String? chequeNo,
    int? chequeDate,
    String? chequeDateBs,
    String? referenceNo,
    int? clearedDate,
    PaymentStatus? status,
    String? description,
    String? remarks,
    String? createdById,
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
    String? supplierName,
    String? purchaseBillNo,
    bool clearClearedDate = false,
  }) =>
      SupplierPayment(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        fiscalYearId: fiscalYearId ?? this.fiscalYearId,
        supplierId: supplierId ?? this.supplierId,
        purchaseId: purchaseId ?? this.purchaseId,
        voucherNo: voucherNo ?? this.voucherNo,
        paymentDate: paymentDate ?? this.paymentDate,
        paymentDateBs: paymentDateBs ?? this.paymentDateBs,
        paymentMode: paymentMode ?? this.paymentMode,
        amount: amount ?? this.amount,
        chequeNo: chequeNo ?? this.chequeNo,
        chequeDate: chequeDate ?? this.chequeDate,
        chequeDateBs: chequeDateBs ?? this.chequeDateBs,
        referenceNo: referenceNo ?? this.referenceNo,
        // `clearedDate: null` cannot mean "clear it" — that is indistinguishable
        // from not passing the argument at all. Cancelling a payment genuinely
        // needs to unset the date, so it says so explicitly.
        clearedDate:
            clearClearedDate ? null : (clearedDate ?? this.clearedDate),
        status: status ?? this.status,
        description: description ?? this.description,
        remarks: remarks ?? this.remarks,
        createdById: createdById ?? this.createdById,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        deviceId: deviceId ?? this.deviceId,
        supplierName: supplierName ?? this.supplierName,
        purchaseBillNo: purchaseBillNo ?? this.purchaseBillNo,
      );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.supplierPayment} (
      id              TEXT PRIMARY KEY,
      fiscal_year_id  TEXT NOT NULL,
      supplier_id     TEXT NOT NULL,
      purchase_id     TEXT,
      voucher_no      TEXT,
      payment_date    INTEGER NOT NULL,
      payment_date_bs TEXT,
      payment_mode    TEXT NOT NULL,
      amount          INTEGER NOT NULL DEFAULT 0,
      cheque_no       TEXT,
      cheque_date     INTEGER,
      cheque_date_bs  TEXT,
      reference_no    TEXT,
      cleared_date    INTEGER,
      status          TEXT NOT NULL DEFAULT 'CLEARED',
      description     TEXT,
      remarks         TEXT,
      created_by      TEXT,
      ${SyncColumns.definition}
    )
  ''';

  /// Mirrors `supplier_payments_fy_voucher_no_key`. Partial on `voucher_no IS
  /// NOT NULL`, because most payments have no voucher number and any number of
  /// those is fine.
  static const String uniqueVoucherSql = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_supplier_payment_fy_voucher
      ON ${DbTables.supplierPayment} (fiscal_year_id, voucher_no)
      WHERE voucher_no IS NOT NULL AND is_deleted = 0
  ''';
}
