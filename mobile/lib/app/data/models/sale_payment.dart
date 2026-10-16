import '../../core/domain/money.dart';
import '../dto/wire_codec.dart';
import '../enums/payment_status.dart';
import '../enums/sale_payment_mode.dart';

/// How one sale was settled.
///
/// Rows rather than a column, so a single sale can be split — part cash, part
/// credit, part cheque. Like [SaleItem] these are created with their sale and
/// are never addressed on their own.
class SalePayment {
  const SalePayment({
    required this.id,
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

  /// Empty on a line the form has built; assigned by the server.
  final String id;

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

  factory SalePayment.fromJson(Map<String, dynamic> json) => SalePayment(
        id: WireCodec.string(json['id']),
        paymentMode: SalePaymentMode.fromValue(
          WireCodec.stringOrNull(json['paymentMode']),
        ),
        amount: WireCodec.money(json['amount']),
        referenceNo: WireCodec.stringOrNull(json['referenceNo']),
        chequeNo: WireCodec.stringOrNull(json['chequeNo']),
        chequeDate: WireCodec.dateMs(json['chequeDate']),
        clearedDate: WireCodec.dateMs(json['clearedDate']),
        status: PaymentStatus.fromValue(WireCodec.stringOrNull(json['status'])),
        remarks: WireCodec.stringOrNull(json['remarks']),
        createdAt: WireCodec.millis(json['createdAt'], fallback: 0),
      );

  /// The settlement line as `POST /sales` accepts it.
  ///
  /// `status` is omitted: the server defaults CREDIT to ISSUED and everything
  /// else to CLEARED, which is the same rule stated once instead of twice.
  Map<String, dynamic> toRequestBody() => {
        'paymentMode': paymentMode.value,
        'amount': amount.toWire(),
        'referenceNo': referenceNo,
        'chequeNo': chequeNo,
        'chequeDate': WireCodec.isoDateOrNull(chequeDate),
        'remarks': remarks,
      };

  SalePayment copyWith({
    String? id,
    SalePaymentMode? paymentMode,
    Money? amount,
    String? referenceNo,
    String? chequeNo,
    int? chequeDate,
    int? clearedDate,
    PaymentStatus? status,
    String? remarks,
  }) =>
      SalePayment(
        id: id ?? this.id,
        paymentMode: paymentMode ?? this.paymentMode,
        amount: amount ?? this.amount,
        referenceNo: referenceNo ?? this.referenceNo,
        chequeNo: chequeNo ?? this.chequeNo,
        chequeDate: chequeDate ?? this.chequeDate,
        clearedDate: clearedDate ?? this.clearedDate,
        status: status ?? this.status,
        remarks: remarks ?? this.remarks,
        createdAt: createdAt,
      );
}
