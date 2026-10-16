import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../dto/wire_codec.dart';
import '../enums/sale_type.dart';
import 'sale_item.dart';
import 'sale_payment.dart';

/// One sale to one customer, at whichever level of detail was written down.
///
///     SUMMARY  - the total was enough ("sold 3 shirts, Rs 4,050"), no items
///     DETAILED - the customer wanted an itemised invoice, so there are items
///
/// A day's takings is not a record here; it is the sum of the day's sales. That
/// is what the day book screen shows.
///
/// [subtotal] and [totalAmount] are derived on the server from the lines and
/// whatever a form sends for them is ignored, so the total and the rows under
/// it cannot disagree.
class Sale {
  const Sale({
    required this.id,
    required this.fiscalYearId,
    required this.saleDate,
    required this.saleType,
    required this.totalAmount,
    this.invoiceNo,
    this.saleDateBs,
    this.customerId,
    this.description,
    this.subtotal = Money.zero,
    this.discount = Money.zero,
    this.remarks,
    this.createdById,
    this.items = const [],
    this.payments = const [],
    this.customerName,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  /// Empty on a draft the form has built and the server has not seen yet.
  final String id;

  final String fiscalYearId;

  /// Null is normal: a summary sale handed nobody an invoice. Unique within a
  /// fiscal year when present.
  final String? invoiceNo;

  final int saleDate;
  final String? saleDateBs;
  final String? customerId;
  final SaleType saleType;
  final String? description;

  final Money subtotal;
  final Money discount;
  final Money totalAmount;

  final String? remarks;
  final String? createdById;

  /// The invoice lines come back only from the detail endpoint — a list shows a
  /// total and a date, and loading every line for every row would be data
  /// nothing on screen draws. The settlement lines come back with both, because
  /// "sold" and "taken" are different figures a list has to keep apart.
  final List<SaleItem> items;
  final List<SalePayment> payments;

  /// Attached by the server for display; not a column.
  final String? customerName;

  final int createdAt;
  final int updatedAt;

  /// What was actually taken, ignoring credit lines and cancelled instruments.
  Money get settledTotal =>
      Money.sum(payments.map((payment) => payment.settledAmount));

  /// What the customer still owes on this sale.
  Money get dueTotal => totalAmount - settledTotal;

  bool get isFullyPaid => payments.isNotEmpty && dueTotal.isZero;

  String get saleDateBsOrDerived =>
      saleDateBs ?? NepaliDate.msToBs(saleDate) ?? '';

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: WireCodec.string(json['id']),
        fiscalYearId: WireCodec.string(json['fiscalYearId']),
        invoiceNo: WireCodec.stringOrNull(json['invoiceNo']),
        saleDate: WireCodec.dateMs(json['saleDate']) ?? 0,
        saleDateBs: WireCodec.stringOrNull(json['saleDateBs']),
        customerId: WireCodec.stringOrNull(json['customerId']),
        saleType: SaleType.fromValue(WireCodec.stringOrNull(json['saleType'])),
        description: WireCodec.stringOrNull(json['description']),
        subtotal: WireCodec.money(json['subtotal']),
        discount: WireCodec.money(json['discount']),
        totalAmount: WireCodec.money(json['totalAmount']),
        remarks: WireCodec.stringOrNull(json['remarks']),
        createdById: WireCodec.stringOrNull(json['createdById']),
        items: WireCodec.objects(json['items']).map(SaleItem.fromJson).toList(),
        payments: WireCodec.objects(json['payments'])
            .map(SalePayment.fromJson)
            .toList(),
        customerName: WireCodec.nestedName(json['customer']),
        createdAt: WireCodec.millis(json['createdAt'], fallback: 0),
        updatedAt: WireCodec.millis(json['updatedAt'], fallback: 0),
      );

  /// The body `POST /sales` accepts.
  ///
  /// `subtotal` is absent and `totalAmount` is sent only for a summary sale,
  /// because that is the only shape where it is an input rather than a result.
  /// For an itemised sale the lines are the truth and the server derives the
  /// totals from them; sending a figure it is going to recompute would only
  /// invite the two to differ.
  Map<String, dynamic> toRequestBody() => {
        if (fiscalYearId.isNotEmpty) 'fiscalYearId': fiscalYearId,
        'invoiceNo': invoiceNo,
        'saleDate': WireCodec.isoDate(saleDate),
        'saleDateBs': saleDateBs ?? NepaliDate.msToBs(saleDate),
        'customerId': customerId,
        'saleType': saleType.value,
        'description': description,
        'discount': discount.toWire(),
        if (!saleType.hasItems) 'totalAmount': totalAmount.toWire(),
        'items': [for (final item in items) item.toRequestBody()],
        'payments': [for (final payment in payments) payment.toRequestBody()],
        'remarks': remarks,
      };

  Sale copyWith({
    String? invoiceNo,
    int? saleDate,
    String? saleDateBs,
    String? customerId,
    SaleType? saleType,
    String? description,
    Money? subtotal,
    Money? discount,
    Money? totalAmount,
    String? remarks,
    List<SaleItem>? items,
    List<SalePayment>? payments,
    String? customerName,
  }) =>
      Sale(
        id: id,
        fiscalYearId: fiscalYearId,
        invoiceNo: invoiceNo ?? this.invoiceNo,
        saleDate: saleDate ?? this.saleDate,
        saleDateBs: saleDateBs ?? this.saleDateBs,
        customerId: customerId ?? this.customerId,
        saleType: saleType ?? this.saleType,
        description: description ?? this.description,
        subtotal: subtotal ?? this.subtotal,
        discount: discount ?? this.discount,
        totalAmount: totalAmount ?? this.totalAmount,
        remarks: remarks ?? this.remarks,
        createdById: createdById,
        items: items ?? this.items,
        payments: payments ?? this.payments,
        customerName: customerName ?? this.customerName,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
