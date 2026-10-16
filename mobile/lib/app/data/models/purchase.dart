import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../dto/wire_codec.dart';

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
/// payments are separate records, so partial, credit, cash-plus-cheque and
/// future-dated settlements are all expressible. [paidTotal] is derived by the
/// server from those payments.
class Purchase {
  const Purchase({
    required this.id,
    required this.fiscalYearId,
    required this.supplierId,
    required this.billNo,
    required this.billDate,
    required this.amount,
    this.billDateBs,
    this.description,
    this.remarks,
    this.createdById,
    this.supplierName,
    this.paidTotal,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  /// Empty on a draft the form has built and the server has not seen yet.
  final String id;

  final String fiscalYearId;
  final String supplierId;

  /// Copied off the wholesaler's paper bill, so it is only unique per supplier
  /// per fiscal year — two suppliers may legitimately both issue a "4521".
  final String billNo;

  /// AD, as the epoch millis every list sorts and ranges on.
  final int billDate;

  /// The BS string written on the bill, kept for display and printing.
  final String? billDateBs;

  final String? description;
  final Money amount;
  final String? remarks;
  final String? createdById;

  /// Attached by the server for display; not a column.
  final String? supplierName;

  /// Settled against this bill, cancelled payments excluded. Null when the
  /// payload did not carry it.
  final Money? paidTotal;

  final int createdAt;
  final int updatedAt;

  Money? get dueTotal => paidTotal == null ? null : amount - paidTotal!;

  bool get isFullyPaid => dueTotal?.isZero ?? false;

  String get billDateBsOrDerived =>
      billDateBs ?? NepaliDate.msToBs(billDate) ?? '';

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: WireCodec.string(json['id']),
        fiscalYearId: WireCodec.string(json['fiscalYearId']),
        supplierId: WireCodec.string(json['supplierId']),
        billNo: WireCodec.string(json['billNo']),
        billDate: WireCodec.dateMs(json['billDate']) ?? 0,
        billDateBs: WireCodec.stringOrNull(json['billDateBs']),
        description: WireCodec.stringOrNull(json['description']),
        amount: WireCodec.money(json['amount']),
        remarks: WireCodec.stringOrNull(json['remarks']),
        createdById: WireCodec.stringOrNull(json['createdById']),
        supplierName: WireCodec.nestedName(json['supplier']),
        paidTotal: json.containsKey('paidTotal')
            ? WireCodec.money(json['paidTotal'])
            : null,
        createdAt: WireCodec.millis(json['createdAt'], fallback: 0),
        updatedAt: WireCodec.millis(json['updatedAt'], fallback: 0),
      );

  /// The body `POST /purchases` accepts.
  ///
  /// The BS date is filled in from the AD date when the form did not supply
  /// one, so a bill saved from a screen that only offered an AD picker still
  /// prints correctly. When the form *did* supply one it wins — it is what was
  /// written on the paper.
  Map<String, dynamic> toRequestBody() => {
        if (fiscalYearId.isNotEmpty) 'fiscalYearId': fiscalYearId,
        'supplierId': supplierId,
        'billNo': billNo,
        'billDate': NepaliDate.toIsoDate(NepaliDate.fromMs(billDate)),
        'billDateBs': billDateBs ?? NepaliDate.msToBs(billDate),
        'description': description,
        'amount': amount.toWire(),
        'remarks': remarks,
      };

  Purchase copyWith({
    String? billNo,
    int? billDate,
    String? billDateBs,
    String? description,
    Money? amount,
    String? remarks,
    String? supplierName,
    Money? paidTotal,
  }) =>
      Purchase(
        id: id,
        fiscalYearId: fiscalYearId,
        supplierId: supplierId,
        billNo: billNo ?? this.billNo,
        billDate: billDate ?? this.billDate,
        billDateBs: billDateBs ?? this.billDateBs,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        remarks: remarks ?? this.remarks,
        createdById: createdById,
        supplierName: supplierName ?? this.supplierName,
        paidTotal: paidTotal ?? this.paidTotal,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
