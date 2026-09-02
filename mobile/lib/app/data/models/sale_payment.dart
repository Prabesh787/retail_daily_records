import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/payment_status.dart';
import '../enums/sale_payment_mode.dart';
import 'base/syncable_model.dart';

/// How one sale was settled.
///
/// Rows rather than a column, so a single sale can be split — part cash, part
/// credit, part cheque. Like [SaleItem] these travel inside the sale's payload
/// and never sync on their own.
class SalePayment {
  const SalePayment({
    required this.id,
    required this.saleId,
    required this.paymentMode,
    required this.amount,
    this.referenceNo,
    this.chequeNo,
    this.chequeDate,
    this.clearedDate,
    this.status = PaymentStatus.cleared,
    this.remarks,
    this.createdAt = 0,
  });

  final String id;
  final String saleId;
  final SalePaymentMode paymentMode;
  final Money amount;
  final String? referenceNo;
  final String? chequeNo;
  final int? chequeDate;
  final int? clearedDate;
  final PaymentStatus status;
  final String? remarks;
  final int createdAt;

  /// Money actually taken.
  ///
  /// A credit line is a promise, not takings — counting it is how a day's till
  /// stops matching the day book.
  Money get settledAmount =>
      paymentMode.isSettled && status.reducesLiability ? amount : Money.zero;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'payment_mode': paymentMode.value,
        'amount': amount.toColumn(),
        'reference_no': referenceNo,
        'cheque_no': chequeNo,
        'cheque_date': chequeDate,
        'cleared_date': clearedDate,
        'status': status.value,
        'remarks': remarks,
        'created_at': createdAt,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'saleId': saleId,
        'paymentMode': paymentMode.value,
        'amount': amount.toWire(),
        'referenceNo': referenceNo,
        'chequeNo': chequeNo,
        'chequeDate': _isoOrNull(chequeDate),
        'clearedDate': _isoOrNull(clearedDate),
        'status': status.value,
        'remarks': remarks,
      };

  static String? _isoOrNull(int? ms) =>
      ms == null ? null : NepaliDate.toIsoDate(NepaliDate.fromMs(ms));

  factory SalePayment.fromMap(Map<String, dynamic> map) => SalePayment(
        id: (map['id'] as String?) ?? '',
        saleId: (map['sale_id'] as String?) ?? '',
        paymentMode: SalePaymentMode.fromValue(map['payment_mode'] as String?),
        amount: Money.fromColumn(map['amount']),
        referenceNo: map['reference_no'] as String?,
        chequeNo: map['cheque_no'] as String?,
        chequeDate: map['cheque_date'] as int?,
        clearedDate: map['cleared_date'] as int?,
        status: PaymentStatus.fromValue(map['status'] as String?),
        remarks: map['remarks'] as String?,
        createdAt: SyncableModel.toInt(map['created_at']),
      );

  SalePayment copyWith({
    String? saleId,
    SalePaymentMode? paymentMode,
    Money? amount,
    String? referenceNo,
    String? chequeNo,
    int? chequeDate,
    int? clearedDate,
    PaymentStatus? status,
    String? remarks,
    int? createdAt,
  }) =>
      SalePayment(
        id: id,
        saleId: saleId ?? this.saleId,
        paymentMode: paymentMode ?? this.paymentMode,
        amount: amount ?? this.amount,
        referenceNo: referenceNo ?? this.referenceNo,
        chequeNo: chequeNo ?? this.chequeNo,
        chequeDate: chequeDate ?? this.chequeDate,
        clearedDate: clearedDate ?? this.clearedDate,
        status: status ?? this.status,
        remarks: remarks ?? this.remarks,
        createdAt: createdAt ?? this.createdAt,
      );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.salePayment} (
      id           TEXT PRIMARY KEY,
      sale_id      TEXT NOT NULL,
      payment_mode TEXT NOT NULL,
      amount       INTEGER NOT NULL DEFAULT 0,
      reference_no TEXT,
      cheque_no    TEXT,
      cheque_date  INTEGER,
      cleared_date INTEGER,
      status       TEXT NOT NULL DEFAULT 'CLEARED',
      remarks      TEXT,
      created_at   INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (sale_id) REFERENCES ${DbTables.sale} (id) ON DELETE CASCADE
    )
  ''';
}
