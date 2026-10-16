import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../dto/wire_codec.dart';
import '../enums/payment_status.dart';
import '../enums/supplier_payment_mode.dart';

/// Money the shop paid a supplier.
///
/// Stored apart from the purchase it settles — never as a `paid_amount` column
/// — so that partial, credit, cash-plus-cheque and future-dated-cheque
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
class SupplierPayment {
  const SupplierPayment({
    required this.id,
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
    this.supplierName,
    this.purchaseBillNo,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  /// Empty on a draft the form has built and the server has not seen yet.
  final String id;

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

  /// Attached by the server for display; not columns.
  final String? supplierName;
  final String? purchaseBillNo;

  final int createdAt;
  final int updatedAt;

  /// What this payment contributes to the supplier's balance. A cancelled
  /// payment settled nothing.
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

  factory SupplierPayment.fromJson(Map<String, dynamic> json) {
    final purchase = json['purchase'];

    return SupplierPayment(
      id: WireCodec.string(json['id']),
      fiscalYearId: WireCodec.string(json['fiscalYearId']),
      supplierId: WireCodec.string(json['supplierId']),
      purchaseId: WireCodec.stringOrNull(json['purchaseId']),
      voucherNo: WireCodec.stringOrNull(json['voucherNo']),
      paymentDate: WireCodec.dateMs(json['paymentDate']) ?? 0,
      paymentDateBs: WireCodec.stringOrNull(json['paymentDateBs']),
      paymentMode: SupplierPaymentMode.fromValue(
        WireCodec.stringOrNull(json['paymentMode']),
      ),
      amount: WireCodec.money(json['amount']),
      chequeNo: WireCodec.stringOrNull(json['chequeNo']),
      chequeDate: WireCodec.dateMs(json['chequeDate']),
      chequeDateBs: WireCodec.stringOrNull(json['chequeDateBs']),
      referenceNo: WireCodec.stringOrNull(json['referenceNo']),
      clearedDate: WireCodec.dateMs(json['clearedDate']),
      status: PaymentStatus.fromValue(WireCodec.stringOrNull(json['status'])),
      description: WireCodec.stringOrNull(json['description']),
      remarks: WireCodec.stringOrNull(json['remarks']),
      createdById: WireCodec.stringOrNull(json['createdById']),
      supplierName: WireCodec.nestedName(json['supplier']),
      purchaseBillNo: purchase is Map
          ? WireCodec.stringOrNull(purchase['billNo'])
          : null,
      createdAt: WireCodec.millis(json['createdAt'], fallback: 0),
      updatedAt: WireCodec.millis(json['updatedAt'], fallback: 0),
    );
  }

  /// The body `POST /supplier-payments` accepts.
  ///
  /// The cheque fields travel only for a cheque and the reference only for the
  /// modes that have one: the server refuses cheque details on a cash payment
  /// outright, which is the right rule and one the form must not fight.
  ///
  /// `status` and `clearedDate` are left out on purpose. Cash is cleared the
  /// moment it changes hands and a cheque is only issued until the bank pays
  /// it, and the server applies exactly that default — stating it here as well
  /// would be two places for one rule to live.
  Map<String, dynamic> toRequestBody() {
    final isCheque = paymentMode.isCheque;

    return {
      if (fiscalYearId.isNotEmpty) 'fiscalYearId': fiscalYearId,
      'supplierId': supplierId,
      'purchaseId': purchaseId,
      'voucherNo': voucherNo,
      'paymentDate': WireCodec.isoDate(paymentDate),
      'paymentDateBs': paymentDateBs ?? NepaliDate.msToBs(paymentDate),
      'paymentMode': paymentMode.value,
      'amount': amount.toWire(),
      'chequeNo': isCheque ? chequeNo : null,
      // A cheque handed over with no date written on it is dated the day it
      // changed hands, which is what the register then plans around — and the
      // server requires one, so there is nowhere for a blank to go.
      'chequeDate':
          isCheque ? WireCodec.isoDate(chequeDate ?? paymentDate) : null,
      'chequeDateBs': isCheque
          ? (chequeDateBs ?? NepaliDate.msToBs(chequeDate ?? paymentDate))
          : null,
      'referenceNo': paymentMode.hasReference ? referenceNo : null,
      'description': description,
      'remarks': remarks,
    };
  }

  SupplierPayment copyWith({
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
    String? supplierName,
    String? purchaseBillNo,
    bool clearClearedDate = false,
  }) =>
      SupplierPayment(
        id: id,
        fiscalYearId: fiscalYearId,
        supplierId: supplierId,
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
        // `clearedDate: null` cannot mean "clear it" — that is
        // indistinguishable from not passing the argument at all. Cancelling a
        // payment genuinely needs to unset the date, so it says so explicitly.
        clearedDate:
            clearClearedDate ? null : (clearedDate ?? this.clearedDate),
        status: status ?? this.status,
        description: description ?? this.description,
        remarks: remarks ?? this.remarks,
        createdById: createdById,
        supplierName: supplierName ?? this.supplierName,
        purchaseBillNo: purchaseBillNo ?? this.purchaseBillNo,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
