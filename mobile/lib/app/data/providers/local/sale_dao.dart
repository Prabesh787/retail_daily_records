import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/domain/money.dart';
import '../../../core/utils/nepali_date.dart';
import '../../enums/sale_type.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../models/sale_payment.dart';

/// One day's takings — the shape the sales list and the day book both read.
class SalesDay {
  const SalesDay({
    required this.dateMs,
    required this.total,
    required this.count,
    this.dateBs,
    this.sales = const [],
  });

  final int dateMs;
  final String? dateBs;
  final Money total;
  final int count;

  /// Populated by the day book; empty in the grouped list.
  final List<Sale> sales;
}

class SaleDao {
  const SaleDao(this._db);

  final Database _db;

  static String get _select => '''
    SELECT s.*, c.name AS customer_name
    FROM ${DbTables.sale} s
    LEFT JOIN ${DbTables.customer} c ON c.id = s.customer_id
  ''';

  /// Headers only — lines and payments are left off deliberately.
  ///
  /// A list screen shows a total and a date; loading every line for every row
  /// would be N+1 queries for data nothing on screen displays. [byId] loads the
  /// whole document.
  Future<List<Sale>> all({
    String? customerId,
    String? fiscalYearId,
    SaleType? saleType,
    int? fromMs,
    int? toMs,
    String? search,
    int? limit,
  }) async {
    final where = <String>['s.is_deleted = 0'];
    final args = <Object?>[];

    if (customerId != null) {
      where.add('s.customer_id = ?');
      args.add(customerId);
    }
    if (fiscalYearId != null) {
      where.add('s.fiscal_year_id = ?');
      args.add(fiscalYearId);
    }
    if (saleType != null) {
      where.add('s.sale_type = ?');
      args.add(saleType.value);
    }
    if (fromMs != null) {
      where.add('s.sale_date >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('s.sale_date <= ?');
      args.add(toMs);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(s.invoice_no LIKE ? OR s.description LIKE ? OR c.name LIKE ?)');
      final term = '%${search.trim()}%';
      args..add(term)..add(term)..add(term);
    }

    final rows = await _db.rawQuery('''
      $_select WHERE ${where.join(' AND ')}
      ORDER BY s.sale_date DESC, s.created_at DESC
      ${limit == null ? '' : 'LIMIT $limit'}
    ''', args);
    return rows.map(Sale.fromMap).toList();
  }

  /// The whole document: header, lines in the order they were written, and the
  /// payments against it.
  Future<Sale?> byId(String id) async {
    final rows = await _db.rawQuery(
      '$_select WHERE s.id = ? AND s.is_deleted = 0 LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;

    return Sale.fromMap(
      rows.first,
      items: await itemsFor(id),
      payments: await paymentsFor(id),
    );
  }

  Future<List<SaleItem>> itemsFor(String saleId) async {
    final rows = await _db.query(
      DbTables.saleItem,
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(SaleItem.fromMap).toList();
  }

  Future<List<SalePayment>> paymentsFor(String saleId) async {
    final rows = await _db.query(
      DbTables.salePayment,
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'created_at ASC',
    );
    return rows.map(SalePayment.fromMap).toList();
  }

  /// Takings grouped by day, newest first — the sales list's section headers.
  ///
  /// The BS label comes from whichever `sale_date_bs` was recorded that day,
  /// because that is what was written on the paperwork. A day with none falls
  /// back to a conversion.
  Future<List<SalesDay>> byDay({int? fromMs, int? toMs, int? limit}) async {
    final where = <String>['is_deleted = 0'];
    final args = <Object?>[];

    if (fromMs != null) {
      where.add('sale_date >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('sale_date <= ?');
      args.add(toMs);
    }

    final rows = await _db.rawQuery('''
      SELECT sale_date,
        MAX(sale_date_bs) AS sale_date_bs,
        SUM(total_amount) AS total,
        COUNT(*)          AS cnt
      FROM ${DbTables.sale}
      WHERE ${where.join(' AND ')}
      GROUP BY sale_date
      ORDER BY sale_date DESC
      ${limit == null ? '' : 'LIMIT $limit'}
    ''', args);

    return rows.map((row) {
      final dateMs = (row['sale_date'] as int?) ?? 0;
      return SalesDay(
        dateMs: dateMs,
        dateBs: (row['sale_date_bs'] as String?) ?? NepaliDate.msToBs(dateMs),
        total: Money.fromColumn(row['total']),
        count: (row['cnt'] as int?) ?? 0,
      );
    }).toList();
  }

  /// One day in full — every sale made that day, with its lines and payments.
  Future<SalesDay> dayBook(int dateMs) async {
    final headers = await all(fromMs: dateMs, toMs: dateMs);
    final sales = <Sale>[];
    for (final header in headers) {
      sales.add(header.copyWith(
        items: await itemsFor(header.id),
        payments: await paymentsFor(header.id),
      ));
    }

    return SalesDay(
      dateMs: dateMs,
      dateBs: sales
              .map((sale) => sale.saleDateBs)
              .firstWhere((bs) => bs != null, orElse: () => null) ??
          NepaliDate.msToBs(dateMs),
      total: Money.sum(sales.map((sale) => sale.totalAmount)),
      count: sales.length,
      sales: sales,
    );
  }

  Future<({Money total, int count})> totalBetween(int fromMs, int toMs) async {
    final row = (await _db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) AS total, COUNT(*) AS cnt
      FROM ${DbTables.sale}
      WHERE is_deleted = 0 AND sale_date >= ? AND sale_date <= ?
    ''', [fromMs, toMs]))
        .first;

    return (
      total: Money.fromColumn(row['total']),
      count: (row['cnt'] as int?) ?? 0,
    );
  }

  /// Daily totals across a window, for the trend chart.
  ///
  /// Days with no sales are absent — the caller fills the gaps, because a chart
  /// needs every day and a table should not store zeros.
  Future<Map<int, Money>> dailyTotals(int fromMs, int toMs) async {
    final rows = await _db.rawQuery('''
      SELECT sale_date, SUM(total_amount) AS total
      FROM ${DbTables.sale}
      WHERE is_deleted = 0 AND sale_date >= ? AND sale_date <= ?
      GROUP BY sale_date
    ''', [fromMs, toMs]);

    return {
      for (final row in rows)
        (row['sale_date'] as int?) ?? 0: Money.fromColumn(row['total']),
    };
  }

  Future<bool> invoiceNoExists({
    required String fiscalYearId,
    required String invoiceNo,
    String? exceptId,
  }) async {
    final rows = await _db.query(
      DbTables.sale,
      columns: ['id'],
      where: 'fiscal_year_id = ? AND invoice_no = ? AND is_deleted = 0'
          '${exceptId == null ? '' : ' AND id <> ?'}',
      whereArgs: [fiscalYearId, invoiceNo, ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsert(DatabaseExecutor txn, Sale sale) async {
    await txn.insert(
      DbTables.sale,
      sale.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Replaces a sale's lines wholesale.
  ///
  /// Delete-then-insert rather than a diff: invoice lines have no identity the
  /// user cares about, and a diff would have to guess which edited line was
  /// which. Must run inside the same transaction as the header write.
  Future<void> replaceItems(
    DatabaseExecutor txn,
    String saleId,
    List<SaleItem> items,
  ) async {
    await txn.delete(DbTables.saleItem, where: 'sale_id = ?', whereArgs: [saleId]);
    for (final item in items) {
      await txn.insert(DbTables.saleItem, item.toMap());
    }
  }

  Future<void> replacePayments(
    DatabaseExecutor txn,
    String saleId,
    List<SalePayment> payments,
  ) async {
    await txn.delete(
      DbTables.salePayment,
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    for (final payment in payments) {
      await txn.insert(DbTables.salePayment, payment.toMap());
    }
  }

  Future<void> softDelete(DatabaseExecutor txn, String id, int updatedAt) async {
    await txn.update(
      DbTables.sale,
      {
        SyncColumns.isDeleted: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.syncStatus: 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
