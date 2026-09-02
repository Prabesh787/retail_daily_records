import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/sale_type.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';
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
/// [subtotal] and [totalAmount] are derived for an itemised sale — computed
/// from the lines by [recalculated], never accepted from a form. The server
/// does the same on ingest and ignores whatever a client sends, so the two
/// cannot disagree.
class Sale extends SyncableModel {
  const Sale({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
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
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
    this.items = const [],
    this.payments = const [],
    this.customerName,
  });

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

  /// Loaded on demand by the DAO; empty in list queries, because a list shows a
  /// total and a date and loading every line for every row would be N+1 queries
  /// for data nothing on screen displays.
  final List<SaleItem> items;
  final List<SalePayment> payments;

  /// Joined in for display; not a stored column.
  final String? customerName;

  /// What was actually taken, ignoring credit lines and cancelled instruments.
  Money get settledTotal =>
      Money.sum(payments.map((payment) => payment.settledAmount));

  /// What the customer still owes on this sale.
  Money get dueTotal => totalAmount - settledTotal;

  bool get isFullyPaid => payments.isNotEmpty && dueTotal.isZero;

  String get saleDateBsOrDerived =>
      saleDateBs ?? NepaliDate.msToBs(saleDate) ?? '';

  /// This sale with its derived totals recomputed from its own lines.
  ///
  /// The single place an itemised sale's totals are produced. A summary sale has
  /// no lines to derive from, so the figure that was entered is the total and
  /// the subtotal simply matches it.
  Sale get recalculated {
    if (saleType == SaleType.summary) {
      return copyWith(subtotal: totalAmount, discount: Money.zero);
    }
    final lineTotal = Money.sum(items.map((item) => item.amount));
    return copyWith(subtotal: lineTotal, totalAmount: lineTotal - discount);
  }

  @override
  Map<String, dynamic> toMap() => {
        ...syncMap,
        'fiscal_year_id': fiscalYearId,
        'invoice_no': invoiceNo,
        'sale_date': saleDate,
        'sale_date_bs': saleDateBs,
        'customer_id': customerId,
        'sale_type': saleType.value,
        'description': description,
        'subtotal': subtotal.toColumn(),
        'discount': discount.toColumn(),
        'total_amount': totalAmount.toColumn(),
        'remarks': remarks,
        'created_by': createdById,
      };

  /// The lines and the payments ride along with the header so the sale syncs
  /// atomically — a header that landed without its lines would be an accounting
  /// error, not a partial success.
  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'fiscalYearId': fiscalYearId,
        'invoiceNo': invoiceNo,
        'saleDate': NepaliDate.toIsoDate(NepaliDate.fromMs(saleDate)),
        'saleDateBs': saleDateBs,
        'customerId': customerId,
        'saleType': saleType.value,
        'description': description,
        'subtotal': subtotal.toWire(),
        'discount': discount.toWire(),
        'totalAmount': totalAmount.toWire(),
        'remarks': remarks,
        'createdById': createdById,
        'items': items.map((item) => item.toJson()).toList(),
        'payments': payments.map((payment) => payment.toJson()).toList(),
        ...syncJson,
      };

  factory Sale.fromMap(
    Map<String, dynamic> map, {
    List<SaleItem>? items,
    List<SalePayment>? payments,
  }) =>
      Sale(
        id: SyncableModel.idOf(map),
        createdAt: SyncableModel.createdAtOf(map),
        updatedAt: SyncableModel.updatedAtOf(map),
        isDeleted: SyncableModel.isDeletedOf(map),
        syncStatus: SyncableModel.syncStatusOf(map),
        deviceId: SyncableModel.deviceIdOf(map),
        fiscalYearId: (map['fiscal_year_id'] as String?) ?? '',
        invoiceNo: map['invoice_no'] as String?,
        saleDate: SyncableModel.toInt(map['sale_date']),
        saleDateBs: map['sale_date_bs'] as String?,
        customerId: map['customer_id'] as String?,
        saleType: SaleType.fromValue(map['sale_type'] as String?),
        description: map['description'] as String?,
        subtotal: Money.fromColumn(map['subtotal']),
        discount: Money.fromColumn(map['discount']),
        totalAmount: Money.fromColumn(map['total_amount']),
        remarks: map['remarks'] as String?,
        createdById: map['created_by'] as String?,
        items: items ?? const [],
        payments: payments ?? const [],
        customerName: map['customer_name'] as String?,
      );

  Sale copyWith({
    String? fiscalYearId,
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
    String? createdById,
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
    List<SaleItem>? items,
    List<SalePayment>? payments,
    String? customerName,
  }) =>
      Sale(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        fiscalYearId: fiscalYearId ?? this.fiscalYearId,
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
        createdById: createdById ?? this.createdById,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        deviceId: deviceId ?? this.deviceId,
        items: items ?? this.items,
        payments: payments ?? this.payments,
        customerName: customerName ?? this.customerName,
      );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.sale} (
      id             TEXT PRIMARY KEY,
      fiscal_year_id TEXT NOT NULL,
      invoice_no     TEXT,
      sale_date      INTEGER NOT NULL,
      sale_date_bs   TEXT,
      customer_id    TEXT,
      sale_type      TEXT NOT NULL,
      description    TEXT,
      subtotal       INTEGER NOT NULL DEFAULT 0,
      discount       INTEGER NOT NULL DEFAULT 0,
      total_amount   INTEGER NOT NULL DEFAULT 0,
      remarks        TEXT,
      created_by     TEXT,
      ${SyncColumns.definition}
    )
  ''';

  /// Mirrors `sales_fy_invoice_no_key`. Partial on `invoice_no IS NOT NULL`,
  /// which is exactly what summary sales need — any number of them carry none.
  static const String uniqueInvoiceSql = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_sale_fy_invoice_no
      ON ${DbTables.sale} (fiscal_year_id, invoice_no)
      WHERE invoice_no IS NOT NULL AND is_deleted = 0
  ''';
}
