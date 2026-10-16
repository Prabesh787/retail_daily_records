import '../../core/constants/entities.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/sale_payment_mode.dart';
import '../enums/sale_type.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import '../models/supplier_payment.dart';
import 'base_repository.dart';

class SaleRepository extends BaseRepository {
  @override
  String get entity => Entities.sale;

  Future<List<Sale>> list({
    String? customerId,
    String? fiscalYearId,
    SaleType? saleType,
    int? fromMs,
    int? toMs,
    String? search,
    int? limit,
  }) async {
    final response = await api.sales(
      query: {
        ...window(fromMs: fromMs, toMs: toMs),
        'customerId': customerId,
        'fiscalYearId': fiscalYearId,
        'saleType': saleType?.value,
        'q': search,
        'limit': pageSize(limit),
      },
    );
    return response.rows.map(Sale.fromJson).toList();
  }

  Future<Sale?> byId(String id) async {
    if (id.isEmpty) return null;
    try {
      final response = await api.sale(id);
      return Sale.fromJson(response.object);
    } on ValidationException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Everything that happened on one day: what was sold, how it was settled,
  /// and the money that went the other way.
  ///
  /// A shop's day is its takings *and* the bills it took on *and* the suppliers
  /// it paid, and no single list answers that. The API assembles all three in
  /// one round trip, which is also what stops the figures at the top of the
  /// screen drifting from the rows beneath them.
  Future<DayBook> dayBook(int dateMs) async {
    final response = await api.dayBook(
      NepaliDate.toIsoDate(NepaliDate.fromMs(dateMs)),
    );
    return DayBook.fromJson(response.object, fallbackDateMs: dateMs);
  }

  /// Records a sale, its lines and its settlement as one document.
  ///
  /// The totals of an itemised sale are **not** sent: the server derives them
  /// from the lines, exactly as the form previews them, and a figure sent
  /// alongside the lines it is computed from is only ever a second opinion
  /// waiting to be wrong.
  Future<Sale> save(Sale sale) async {
    if (sale.saleType.hasItems && sale.items.isEmpty) {
      throw const ValidationException(
        'An itemised sale needs at least one line.',
      );
    }
    if (!sale.saleType.hasItems && !sale.totalAmount.isPositive) {
      throw const ValidationException('A sale total has to be more than zero.');
    }

    return write(() async {
      final response = await api.createSale(sale.toRequestBody());
      return Sale.fromJson(response.object);
    });
  }

  Future<void> delete(String id) => write(() => api.deleteSale(id));
}

/// One day of trading, from both sides of the counter.
///
/// The takings figure and the split beneath it are computed from the sales
/// themselves, because there is no "day's takings" record anywhere in this
/// system by design — the day is the sum of what is under it, and a stored
/// total would be one more thing that can drift.
class DayBook {
  const DayBook({
    required this.dateMs,
    required this.sales,
    required this.purchases,
    required this.payments,
    this.dateBs,
  });

  factory DayBook.fromJson(
    Map<String, dynamic> json, {
    required int fallbackDateMs,
  }) {
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) read) =>
        (json[key] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(read)
            .toList();

    final date = json['date'];
    final parsed = date == null
        ? null
        : NepaliDate.parseIsoDate(date.toString())?.millisecondsSinceEpoch;

    return DayBook(
      dateMs: parsed ?? fallbackDateMs,
      dateBs: json['dateBs']?.toString(),
      sales: rows('sales', Sale.fromJson),
      purchases: rows('purchases', Purchase.fromJson),
      payments: rows('payments', SupplierPayment.fromJson),
    );
  }

  final int dateMs;
  final String? dateBs;

  final List<Sale> sales;

  /// Bills dated this day, and supplier payments dated this day. Money going
  /// out, which is the half a sales-only screen would leave the shopkeeper to
  /// work out for themselves.
  final List<Purchase> purchases;
  final List<SupplierPayment> payments;

  bool get isEmpty => sales.isEmpty && purchases.isEmpty && payments.isEmpty;

  /// What was sold. Includes credit — this is turnover, not cash.
  Money get salesTotal => Money.sum(sales.map((sale) => sale.totalAmount));

  int get saleCount => sales.length;

  /// What was actually taken. Credit lines and cancelled instruments are worth
  /// nothing today, which is the whole reason this is a separate figure from
  /// [salesTotal]: a shop whose till has to match the day book needs the one
  /// that excludes promises.
  Money get received => Money.sum(sales.map((sale) => sale.settledTotal));

  /// Sold but not yet paid for — the gap between the two figures above.
  Money get onCredit => salesTotal - received;

  Money get purchaseTotal => Money.sum(purchases.map((p) => p.amount));

  Money get paymentTotal => Money.sum(payments.map((p) => p.recognisedAmount));

  /// Takings split by how each was settled, largest first.
  ///
  /// Built from the payment lines rather than from the sale headers, because a
  /// single sale can be settled two ways — half cash, half on account — and a
  /// header-level split would have to pick one and be wrong about the other.
  List<({SalePaymentMode mode, Money amount})> get byMode {
    final totals = <SalePaymentMode, Money>{};

    for (final sale in sales) {
      for (final payment in sale.payments) {
        // Cancelled instruments are excluded: a bounced cheque was never
        // takings, and leaving it in makes the split disagree with [received].
        if (!payment.status.reducesLiability) continue;

        totals[payment.paymentMode] =
            (totals[payment.paymentMode] ?? Money.zero) + payment.amount;
      }
    }

    return [
      for (final entry in totals.entries) (mode: entry.key, amount: entry.value),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
  }
}
