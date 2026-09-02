import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/domain/money.dart';
import '../../enums/payment_status.dart';
import '../../models/purchase.dart';

class PurchaseDao {
  const PurchaseDao(this._db);

  final Database _db;

  static final String _cancelled = PaymentStatus.cancelled.value;

  /// Purchases with the supplier's name joined in for the list row, and what
  /// has been paid against each bill.
  ///
  /// `paid_total` counts every payment tied to the bill that is not cancelled —
  /// an issued cheque included, because the shop has parted with it. Derived
  /// here rather than kept as a column, for the same reason the supplier
  /// balance is.
  static String get _select => '''
    SELECT p.*,
      s.name AS supplier_name,
      COALESCE(pay.total, 0) AS paid_total
    FROM ${DbTables.purchase} p
    LEFT JOIN ${DbTables.supplier} s ON s.id = p.supplier_id
    LEFT JOIN (
      SELECT purchase_id, SUM(amount) AS total
      FROM ${DbTables.supplierPayment}
      WHERE is_deleted = 0 AND status <> '$_cancelled' AND purchase_id IS NOT NULL
      GROUP BY purchase_id
    ) pay ON pay.purchase_id = p.id
  ''';

  Future<List<Purchase>> all({
    String? supplierId,
    String? fiscalYearId,
    int? fromMs,
    int? toMs,
    String? search,
    bool onlyUnpaid = false,
    int? limit,
  }) async {
    final where = <String>['p.is_deleted = 0'];
    final args = <Object?>[];

    if (supplierId != null) {
      where.add('p.supplier_id = ?');
      args.add(supplierId);
    }
    if (fiscalYearId != null) {
      where.add('p.fiscal_year_id = ?');
      args.add(fiscalYearId);
    }
    if (fromMs != null) {
      where.add('p.bill_date >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('p.bill_date <= ?');
      args.add(toMs);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(p.bill_no LIKE ? OR p.description LIKE ? OR s.name LIKE ?)');
      final term = '%${search.trim()}%';
      args..add(term)..add(term)..add(term);
    }
    if (onlyUnpaid) where.add('COALESCE(pay.total, 0) < p.amount');

    final rows = await _db.rawQuery('''
      $_select WHERE ${where.join(' AND ')}
      ORDER BY p.bill_date DESC, p.created_at DESC
      ${limit == null ? '' : 'LIMIT $limit'}
    ''', args);
    return rows.map(Purchase.fromMap).toList();
  }

  Future<Purchase?> byId(String id) async {
    final rows = await _db.rawQuery(
      '$_select WHERE p.id = ? AND p.is_deleted = 0 LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : Purchase.fromMap(rows.first);
  }

  /// Whether this supplier already has this bill number in this year.
  ///
  /// The unique index would refuse the insert anyway; asking first is what lets
  /// the form say so in words instead of surfacing a database exception.
  Future<bool> billNoExists({
    required String supplierId,
    required String fiscalYearId,
    required String billNo,
    String? exceptId,
  }) async {
    final rows = await _db.query(
      DbTables.purchase,
      columns: ['id'],
      where: 'supplier_id = ? AND fiscal_year_id = ? AND bill_no = ? '
          'AND is_deleted = 0${exceptId == null ? '' : ' AND id <> ?'}',
      whereArgs: [supplierId, fiscalYearId, billNo, ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Total bought in a window — the dashboard's and the report screen's
  /// purchase figure.
  Future<({Money total, int count})> totalBetween(int fromMs, int toMs) async {
    final row = (await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total, COUNT(*) AS cnt
      FROM ${DbTables.purchase}
      WHERE is_deleted = 0 AND bill_date >= ? AND bill_date <= ?
    ''', [fromMs, toMs]))
        .first;

    return (
      total: Money.fromColumn(row['total']),
      count: (row['cnt'] as int?) ?? 0,
    );
  }

  Future<void> upsert(DatabaseExecutor txn, Purchase purchase) async {
    await txn.insert(
      DbTables.purchase,
      purchase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDelete(DatabaseExecutor txn, String id, int updatedAt) async {
    await txn.update(
      DbTables.purchase,
      {
        SyncColumns.isDeleted: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.syncStatus: 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// True when a payment has been recorded against this bill. Voiding it would
  /// leave those payments pointing at nothing.
  Future<bool> hasPayments(String id) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DbTables.supplierPayment} '
      'WHERE purchase_id = ? AND is_deleted = 0',
      [id],
    );
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }
}
