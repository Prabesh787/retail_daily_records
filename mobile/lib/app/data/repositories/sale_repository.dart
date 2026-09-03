import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/sale_payment_mode.dart';
import '../enums/sale_type.dart';
import '../enums/sync_status.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/sale_payment.dart';
import '../models/supplier_payment.dart';
import '../providers/local/sale_dao.dart';
import 'base_repository.dart';

class SaleRepository extends BaseRepository {
  @override
  String get entity => DbTables.sale;

  Future<List<Sale>> list({
    String? customerId,
    String? fiscalYearId,
    SaleType? saleType,
    int? fromMs,
    int? toMs,
    String? search,
    int? limit,
  }) =>
      dbService.sales.all(
        customerId: customerId,
        fiscalYearId: fiscalYearId,
        saleType: saleType,
        fromMs: fromMs,
        toMs: toMs,
        search: search,
        limit: limit,
      );

  Future<Sale?> byId(String id) => dbService.sales.byId(id);

  Future<List<SalesDay>> byDay({int? fromMs, int? toMs, int? limit}) =>
      dbService.sales.byDay(fromMs: fromMs, toMs: toMs, limit: limit);

  Future<SalesDay> dayBook(int dateMs) => dbService.sales.dayBook(dateMs);

  /// Everything that happened on one day: what was sold, how it was settled,
  /// and the money that went the other way.
  ///
  /// The day screen asks a question no single table answers — a shop's day is
  /// its takings *and* the bills it took on *and* the suppliers it paid — so
  /// the three reads are assembled here rather than in the screen. Doing it in
  /// the controller would put a join in the widget layer and leave the figures
  /// one refactor away from disagreeing with the lists beneath them.
  Future<DayBook> dayBookFull(int dateMs) async {
    final day = await dbService.sales.dayBook(dateMs);

    // Both are day-bounded on their own date columns: a bill dated today and a
    // payment dated today, regardless of when either was keyed in.
    final purchases = await dbService.purchases.all(
      fromMs: dateMs,
      toMs: dateMs,
    );
    final payments = await dbService.supplierPayments.all(
      fromMs: dateMs,
      toMs: dateMs,
    );

    return DayBook(day: day, purchases: purchases, payments: payments);
  }

  Future<({Money total, int count})> totalBetween(int fromMs, int toMs) =>
      dbService.sales.totalBetween(fromMs, toMs);

  Future<Map<int, Money>> dailyTotals(int fromMs, int toMs) =>
      dbService.sales.dailyTotals(fromMs, toMs);

  /// Records a sale, its lines and its settlement as one document.
  ///
  /// Three things happen here that are not negotiable:
  ///
  /// 1. **Totals are derived, never accepted.** [Sale.recalculated] recomputes
  ///    the subtotal and total from the lines, exactly as the server does on
  ///    ingest, so whatever a form put in those fields is ignored.
  /// 2. **Header, lines and payments commit together.** A sale whose lines
  ///    half-landed would show a total that does not match its own rows.
  /// 3. **The whole document goes into the outbox as one operation**, because
  ///    that is how the sync contract carries it.
  Future<Sale> save(Sale sale) async {
    if (sale.fiscalYearId.isEmpty) {
      throw const ValidationException(
        'There is no fiscal year to file this sale under.',
      );
    }
    if (sale.saleType.hasItems && sale.items.isEmpty) {
      throw const ValidationException(
        'An itemised sale needs at least one line.',
      );
    }
    if (!sale.saleType.hasItems && !sale.totalAmount.isPositive) {
      throw const ValidationException('A sale total has to be more than zero.');
    }

    final isNew = sale.id.isEmpty;
    final invoiceNo = sale.invoiceNo?.trim();

    if (invoiceNo != null && invoiceNo.isNotEmpty) {
      if (await dbService.sales.invoiceNoExists(
        fiscalYearId: sale.fiscalYearId,
        invoiceNo: invoiceNo,
        exceptId: isNew ? null : sale.id,
      )) {
        throw ValidationException('Invoice $invoiceNo is already used this year.');
      }
    }

    final timestamp = nowMs;
    final id = isNew ? newId() : sale.id;

    // Lines are re-keyed to the sale before the totals are derived, so a line
    // built by a form that did not know the sale's id yet still points at it.
    final items = <SaleItem>[
      for (var index = 0; index < sale.items.length; index += 1)
        sale.items[index].copyWith(
          saleId: id,
          sortOrder: index,
          createdAt: sale.items[index].createdAt == 0
              ? timestamp
              : sale.items[index].createdAt,
        ),
    ];
    final payments = <SalePayment>[
      for (final payment in sale.payments)
        payment.copyWith(
          saleId: id,
          createdAt: payment.createdAt == 0 ? timestamp : payment.createdAt,
        ),
    ];

    final base = isNew
        ? Sale(
            id: id,
            createdAt: timestamp,
            updatedAt: timestamp,
            fiscalYearId: sale.fiscalYearId,
            invoiceNo: (invoiceNo?.isEmpty ?? true) ? null : invoiceNo,
            saleDate: sale.saleDate,
            saleDateBs: sale.saleDateBs ?? NepaliDate.msToBs(sale.saleDate),
            customerId: sale.customerId,
            saleType: sale.saleType,
            description: sale.description,
            discount: sale.discount,
            totalAmount: sale.totalAmount,
            remarks: sale.remarks,
            createdById: sale.createdById,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
            items: items,
            payments: payments,
          )
        : sale.copyWith(
            invoiceNo: (invoiceNo?.isEmpty ?? true) ? null : invoiceNo,
            saleDateBs: sale.saleDateBs ?? NepaliDate.msToBs(sale.saleDate),
            updatedAt: timestamp,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
            items: items,
            payments: payments,
          );

    final stamped = base.recalculated;

    await write((txn) async {
      await dbService.sales.upsert(txn, stamped);
      await dbService.sales.replaceItems(txn, stamped.id, stamped.items);
      await dbService.sales.replacePayments(txn, stamped.id, stamped.payments);
      await enqueue(
        txn,
        entity: DbTables.sale,
        entityId: stamped.id,
        payload: stamped.toJson(),
        updatedAt: timestamp,
      );
    });

    return stamped;
  }

  /// Soft delete.
  ///
  /// The lines and payments are left in place rather than cascaded: the row is
  /// a tombstone, not a hole, and a pull that resurrects the header must find
  /// its lines where it left them. SQLite's `ON DELETE CASCADE` only fires on a
  /// hard delete, which is exactly why this is not one.
  Future<void> delete(String id) async {
    final existing = await byId(id);
    if (existing == null) return;

    final timestamp = nowMs;
    await write((txn) async {
      await dbService.sales.softDelete(txn, id, timestamp);
      await enqueue(
        txn,
        entity: DbTables.sale,
        entityId: id,
        operation: SyncOperationType.delete,
        payload:
            existing.copyWith(isDeleted: true, updatedAt: timestamp).toJson(),
        updatedAt: timestamp,
      );
    });
  }
}

/// One day of trading, from both sides of the counter.
///
/// The takings figure and the split beneath it are computed here from the
/// sales themselves, because there is no "day's takings" record anywhere in
/// this system by design — the day is the sum of what is under it, and a
/// stored total would be one more thing that can drift.
class DayBook {
  DayBook({
    required this.day,
    required this.purchases,
    required this.payments,
  });

  final SalesDay day;

  /// Bills dated this day, and supplier payments dated this day. Money going
  /// out, which is the half a sales-only screen would leave the shopkeeper to
  /// work out for themselves.
  final List<Purchase> purchases;
  final List<SupplierPayment> payments;

  int get dateMs => day.dateMs;
  String? get dateBs => day.dateBs;
  List<Sale> get sales => day.sales;

  bool get isEmpty => sales.isEmpty && purchases.isEmpty && payments.isEmpty;

  /// What was sold. Includes credit — this is turnover, not cash.
  Money get salesTotal => day.total;
  int get saleCount => day.count;

  /// What was actually taken. Credit lines and cancelled instruments are worth
  /// nothing today, which is the whole reason this is a separate figure from
  /// [salesTotal]: a shop whose till has to match the day book needs the one
  /// that excludes promises.
  Money get received =>
      Money.sum(sales.map((sale) => sale.settledTotal));

  /// Sold but not yet paid for — the gap between the two figures above.
  Money get onCredit => salesTotal - received;

  Money get purchaseTotal => Money.sum(purchases.map((p) => p.amount));

  Money get paymentTotal =>
      Money.sum(payments.map((p) => p.recognisedAmount));

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

    final rows = [
      for (final entry in totals.entries)
        (mode: entry.key, amount: entry.value),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    return rows;
  }
}
