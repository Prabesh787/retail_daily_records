import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/payment_status.dart';
import '../enums/supplier_payment_mode.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';

/// Money received from a customer after the sale: "Payment In".
///
/// The mirror of [SupplierPayment], so a cheque behaves the same in both
/// directions: it comes off what the customer owes as soon as it is handed over,
/// and reaches an account only when it clears.
class CustomerPayment extends SyncableModel {
  const CustomerPayment({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.fiscalYearId,
    required this.customerId,
    required this.paymentDate,
    required this.paymentMode,
    required this.amount,
    this.saleId,
    this.voucherNo,
    this.paymentDateBs,
    this.accountId,
    this.chequeNo,
    this.chequeDate,
    this.chequeDateBs,
    this.referenceNo,
    this.clearedDate,
    this.status = PaymentStatus.cleared,
    this.remarks,
    this.createdById,
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
    this.customerName,
    this.accountName,
    this.saleInvoiceNo,
  });

  final String fiscalYearId;
  final String customerId;
  final String? saleId;
  final String? voucherNo;
  final int paymentDate;
  final String? paymentDateBs;
  final SupplierPaymentMode paymentMode;
  final Money amount;
  final String? accountId;
  final String? chequeNo;
  final int? chequeDate;
  final String? chequeDateBs;
  final String? referenceNo;
  final int? clearedDate;
  final PaymentStatus status;
  final String? remarks;
  final String? createdById;

  /// Joined in for display; not stored columns.
  final String? customerName;
  final String? accountName;
  final String? saleInvoiceNo;

  @override
  Map<String, dynamic> toMap() => {
    ...syncMap,
    'fiscal_year_id': fiscalYearId,
    'customer_id': customerId,
    'sale_id': saleId,
    'voucher_no': voucherNo,
    'payment_date': paymentDate,
    'payment_date_bs': paymentDateBs,
    'payment_mode': paymentMode.value,
    'amount': amount.toColumn(),
    'account_id': accountId,
    'cheque_no': chequeNo,
    'cheque_date': chequeDate,
    'cheque_date_bs': chequeDateBs,
    'reference_no': referenceNo,
    'cleared_date': clearedDate,
    'status': status.value,
    'remarks': remarks,
    'created_by': createdById,
  };

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'fiscalYearId': fiscalYearId,
    'customerId': customerId,
    'saleId': saleId,
    'voucherNo': voucherNo,
    'paymentDate': _iso(paymentDate),
    'paymentDateBs': paymentDateBs,
    'paymentMode': paymentMode.value,
    'amount': amount.toWire(),
    'accountId': accountId,
    'chequeNo': chequeNo,
    'chequeDate': _isoOrNull(chequeDate),
    'chequeDateBs': chequeDateBs,
    'referenceNo': referenceNo,
    'clearedDate': _isoOrNull(clearedDate),
    'status': status.value,
    'remarks': remarks,
    'createdById': createdById,
    ...syncJson,
  };

  static String _iso(int ms) => NepaliDate.toIsoDate(NepaliDate.fromMs(ms));
  static String? _isoOrNull(int? ms) => ms == null ? null : _iso(ms);

  factory CustomerPayment.fromMap(Map<String, dynamic> map) => CustomerPayment(
    id: SyncableModel.idOf(map),
    createdAt: SyncableModel.createdAtOf(map),
    updatedAt: SyncableModel.updatedAtOf(map),
    isDeleted: SyncableModel.isDeletedOf(map),
    syncStatus: SyncableModel.syncStatusOf(map),
    deviceId: SyncableModel.deviceIdOf(map),
    fiscalYearId: (map['fiscal_year_id'] as String?) ?? '',
    customerId: (map['customer_id'] as String?) ?? '',
    saleId: map['sale_id'] as String?,
    voucherNo: map['voucher_no'] as String?,
    paymentDate: SyncableModel.toInt(map['payment_date']),
    paymentDateBs: map['payment_date_bs'] as String?,
    paymentMode: SupplierPaymentMode.fromValue(map['payment_mode'] as String?),
    amount: Money.fromColumn(map['amount']),
    accountId: map['account_id'] as String?,
    chequeNo: map['cheque_no'] as String?,
    chequeDate: map['cheque_date'] as int?,
    chequeDateBs: map['cheque_date_bs'] as String?,
    referenceNo: map['reference_no'] as String?,
    clearedDate: map['cleared_date'] as int?,
    status: PaymentStatus.fromValue(map['status'] as String?),
    remarks: map['remarks'] as String?,
    createdById: map['created_by'] as String?,
    customerName: map['customer_name'] as String?,
    accountName: map['account_name'] as String?,
    saleInvoiceNo: map['sale_invoice_no'] as String?,
  );

  CustomerPayment copyWith({
    String? accountId,
    int? clearedDate,
    PaymentStatus? status,
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
    bool clearClearedDate = false,
  }) => CustomerPayment(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    fiscalYearId: fiscalYearId,
    customerId: customerId,
    saleId: saleId,
    voucherNo: voucherNo,
    paymentDate: paymentDate,
    paymentDateBs: paymentDateBs,
    paymentMode: paymentMode,
    amount: amount,
    accountId: accountId ?? this.accountId,
    chequeNo: chequeNo,
    chequeDate: chequeDate,
    chequeDateBs: chequeDateBs,
    referenceNo: referenceNo,
    clearedDate: clearClearedDate ? null : (clearedDate ?? this.clearedDate),
    status: status ?? this.status,
    remarks: remarks,
    createdById: createdById,
    isDeleted: isDeleted ?? this.isDeleted,
    syncStatus: syncStatus ?? this.syncStatus,
    deviceId: deviceId ?? this.deviceId,
    customerName: customerName,
    accountName: accountName,
    saleInvoiceNo: saleInvoiceNo,
  );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.customerPayment} (
      id              TEXT PRIMARY KEY,
      fiscal_year_id  TEXT NOT NULL,
      customer_id     TEXT NOT NULL,
      sale_id         TEXT,
      voucher_no      TEXT,
      payment_date    INTEGER NOT NULL,
      payment_date_bs TEXT,
      payment_mode    TEXT NOT NULL,
      amount          INTEGER NOT NULL DEFAULT 0,
      account_id      TEXT,
      cheque_no       TEXT,
      cheque_date     INTEGER,
      cheque_date_bs  TEXT,
      reference_no    TEXT,
      cleared_date    INTEGER,
      status          TEXT NOT NULL DEFAULT 'CLEARED',
      remarks         TEXT,
      created_by      TEXT,
      ${SyncColumns.definition}
    )
  ''';

  /// Mirrors `customer_payments_fy_voucher_no_key`.
  static const String uniqueVoucherSql = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_customer_payment_fy_voucher
      ON ${DbTables.customerPayment} (fiscal_year_id, voucher_no)
      WHERE voucher_no IS NOT NULL AND is_deleted = 0
  ''';
}
