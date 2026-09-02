import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/sale_type.dart';
import '../enums/sync_status.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/sale_payment.dart';
import '../providers/local/sale_dao.dart';
import 'base_repository.dart';

class SaleRepository extends BaseRepository {
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
