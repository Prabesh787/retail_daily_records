import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/domain/money.dart';
import '../../enums/payment_status.dart';
import '../../models/supplier.dart';

/// What a supplier's books did over one date window.
///
/// The same six figures the statement header and the detail screen's range card
/// both show, so the two cannot disagree about a window they are both looking
/// at. Every one of them is derived; none is stored.
class SupplierWindow {
  const SupplierWindow({
    this.openingAsOf = Money.zero,
    this.purchaseTotal = Money.zero,
    this.paymentTotal = Money.zero,
    this.unclearedTotal = Money.zero,
    this.billCount = 0,
    this.paymentCount = 0,
  });

  /// Owed on the morning the window opens — the balance carried in.
  final Money openingAsOf;

  final Money purchaseTotal;

  /// Payments that settled something. Cancelled ones are not in here.
  final Money paymentTotal;

  /// The part of [paymentTotal] that is cheques the bank has not debited yet.
  final Money unclearedTotal;

  final int billCount;

  /// Counts cancelled payments too: they are listed on the statement.
  final int paymentCount;

  /// The balance carried out. The whole point of the window.
  Money get closing => openingAsOf + purchaseTotal - paymentTotal;

  bool get isEmpty => billCount == 0 && paymentCount == 0;
}

class SupplierDao {
  const SupplierDao(this._db);

  final Database _db;

  // Interpolated from the enum rather than written as literals, so a renamed
  // value is a compile error instead of a query that silently counts nothing.
  static final String _cleared = PaymentStatus.cleared.value;
  static final String _issued = PaymentStatus.issued.value;
  static final String _cancelled = PaymentStatus.cancelled.value;

  /// The one calculation this whole system is built around.
  ///
  ///     outstanding = opening balance + purchases − payments that are not cancelled
  ///
  /// Derived every time it is asked for, never stored, which is why there is no
  /// `current_balance` column here or on the server. A stored total can drift
  /// away from the rows that produced it; this cannot.
  ///
  /// A cheque handed over but not yet debited counts as paid — the shop has
  /// parted with it — while still being reported separately as
  /// `uncleared_total`, because that money has not actually left the bank.
  /// Cancelled payments are excluded outright: a bounced cheque settled nothing.
  ///
  /// Two grouped subqueries rather than correlated ones, so listing every
  /// supplier costs the same as listing one. Mirrors
  /// `backend/src/modules/suppliers/supplier-balance.js`.
  static String get _withBalance => '''
    SELECT s.*,
      COALESCE(pur.total, 0)      AS purchase_total,
      COALESCE(pur.cnt, 0)        AS bill_count,
      COALESCE(pay.cleared, 0)    AS cleared_total,
      COALESCE(pay.uncleared, 0)  AS uncleared_total,
      COALESCE(pay.cnt, 0)        AS payment_count,
      s.opening_balance
        + COALESCE(pur.total, 0)
        - COALESCE(pay.cleared, 0)
        - COALESCE(pay.uncleared, 0) AS outstanding
    FROM ${DbTables.supplier} s
    LEFT JOIN (
      SELECT supplier_id, SUM(amount) AS total, COUNT(*) AS cnt
      FROM ${DbTables.purchase}
      WHERE is_deleted = 0
      GROUP BY supplier_id
    ) pur ON pur.supplier_id = s.id
    LEFT JOIN (
      SELECT supplier_id,
        SUM(CASE WHEN status = '$_cleared' THEN amount ELSE 0 END) AS cleared,
        SUM(CASE WHEN status = '$_issued'  THEN amount ELSE 0 END) AS uncleared,
        COUNT(*) AS cnt
      FROM ${DbTables.supplierPayment}
      WHERE is_deleted = 0 AND status <> '$_cancelled'
      GROUP BY supplier_id
    ) pay ON pay.supplier_id = s.id
  ''';

  Future<List<Supplier>> all({
    String? search,
    bool onlyWithBalance = false,
    bool includeInactive = true,
    int? limit,
  }) async {
    final where = <String>['s.is_deleted = 0'];
    final args = <Object?>[];

    if (!includeInactive) where.add('s.is_active = 1');
    if (search != null && search.trim().isNotEmpty) {
      where.add('(s.name LIKE ? OR s.phone LIKE ? OR s.contact_person LIKE ?)');
      final term = '%${search.trim()}%';
      args..add(term)..add(term)..add(term);
    }

    final rows = await _db.rawQuery('''
      SELECT * FROM ($_withBalance WHERE ${where.join(' AND ')})
      ${onlyWithBalance ? 'WHERE outstanding <> 0' : ''}
      ORDER BY outstanding DESC, name COLLATE NOCASE ASC
      ${limit == null ? '' : 'LIMIT $limit'}
    ''', args);

    return rows.map(Supplier.fromMap).toList();
  }

  Future<Supplier?> byId(String id) async {
    final rows = await _db.rawQuery(
      '$_withBalance WHERE s.id = ? AND s.is_deleted = 0 LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : Supplier.fromMap(rows.first);
  }

  /// Suppliers ranked by what is owed — the dashboard's "owed the most".
  Future<List<Supplier>> topOutstanding({int limit = 4}) async {
    final rows = await _db.rawQuery('''
      SELECT * FROM ($_withBalance WHERE s.is_deleted = 0)
      WHERE outstanding > 0
      ORDER BY outstanding DESC
      LIMIT $limit
    ''');
    return rows.map(Supplier.fromMap).toList();
  }

  /// Total payable across every supplier, and how many are actually owed
  /// anything — the two numbers on the dashboard's payable tile.
  Future<({Money total, int supplierCount})> payable() async {
    final row = (await _db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN outstanding > 0 THEN outstanding ELSE 0 END), 0) AS total,
        COALESCE(SUM(CASE WHEN outstanding > 0 THEN 1 ELSE 0 END), 0) AS cnt
      FROM ($_withBalance WHERE s.is_deleted = 0)
    '''))
        .first;

    return (
      total: Money.fromColumn(row['total']),
      supplierCount: (row['cnt'] as int?) ?? 0,
    );
  }

  /// A supplier's position over one date window.
  ///
  /// The figure that makes this necessary is [openingAsOf] — what was owed on
  /// the morning the window opens. The all-time balance cannot answer it, and
  /// without it a statement has nothing to carry forward from, so the movements
  /// inside the window would appear to start from zero.
  ///
  /// Bounds are inclusive and either may be null, which means "no bound":
  /// a statement with no `from` opens at the supplier's opening balance, which
  /// is exactly right.
  ///
  /// Cancelled payments are excluded from the money but counted in
  /// [paymentCount], because the statement still lists them — a bounced cheque
  /// is part of the audit trail even though it settled nothing.
  Future<SupplierWindow> window(
    String id, {
    int? fromMs,
    int? toMs,
  }) async {
    // Built as fragments rather than with fixed placeholders, so a null bound
    // drops out of the SQL instead of being smuggled in as a sentinel date.
    final priorArgs = <Object?>[];
    final prior = fromMs == null
        ? '0'
        : '''
      COALESCE((
        SELECT SUM(amount) FROM ${DbTables.purchase}
        WHERE supplier_id = s.id AND is_deleted = 0 AND bill_date < ?
      ), 0)
      - COALESCE((
        SELECT SUM(amount) FROM ${DbTables.supplierPayment}
        WHERE supplier_id = s.id AND is_deleted = 0
          AND status <> '$_cancelled' AND payment_date < ?
      ), 0)''';
    if (fromMs != null) priorArgs..add(fromMs)..add(fromMs);

    String range(String column) {
      final parts = <String>[];
      if (fromMs != null) parts.add('AND $column >= ?');
      if (toMs != null) parts.add('AND $column <= ?');
      return parts.join(' ');
    }

    final billArgs = [?fromMs, ?toMs];
    final payArgs = [?fromMs, ?toMs];

    final rows = await _db.rawQuery('''
      SELECT
        s.opening_balance AS opening_balance,
        s.opening_balance + ($prior) AS opening_as_of,
        COALESCE((
          SELECT SUM(amount) FROM ${DbTables.purchase}
          WHERE supplier_id = s.id AND is_deleted = 0 ${range('bill_date')}
        ), 0) AS purchase_total,
        COALESCE((
          SELECT COUNT(*) FROM ${DbTables.purchase}
          WHERE supplier_id = s.id AND is_deleted = 0 ${range('bill_date')}
        ), 0) AS bill_count,
        COALESCE((
          SELECT SUM(amount) FROM ${DbTables.supplierPayment}
          WHERE supplier_id = s.id AND is_deleted = 0
            AND status <> '$_cancelled' ${range('payment_date')}
        ), 0) AS payment_total,
        COALESCE((
          SELECT SUM(amount) FROM ${DbTables.supplierPayment}
          WHERE supplier_id = s.id AND is_deleted = 0
            AND status = '$_issued' ${range('payment_date')}
        ), 0) AS uncleared_total,
        COALESCE((
          SELECT COUNT(*) FROM ${DbTables.supplierPayment}
          WHERE supplier_id = s.id AND is_deleted = 0 ${range('payment_date')}
        ), 0) AS payment_count
      FROM ${DbTables.supplier} s
      WHERE s.id = ? AND s.is_deleted = 0
      LIMIT 1
    ''', [
      ...priorArgs,
      ...billArgs,
      ...billArgs,
      ...payArgs,
      ...payArgs,
      ...payArgs,
      id,
    ]);

    if (rows.isEmpty) return const SupplierWindow();
    final row = rows.first;

    return SupplierWindow(
      openingAsOf: Money.fromColumn(row['opening_as_of']),
      purchaseTotal: Money.fromColumn(row['purchase_total']),
      paymentTotal: Money.fromColumn(row['payment_total']),
      unclearedTotal: Money.fromColumn(row['uncleared_total']),
      billCount: (row['bill_count'] as int?) ?? 0,
      paymentCount: (row['payment_count'] as int?) ?? 0,
    );
  }

  Future<int> count() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DbTables.supplier} WHERE is_deleted = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> nameExists(String name, {String? exceptId}) async {
    final rows = await _db.query(
      DbTables.supplier,
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE AND is_deleted = 0'
          '${exceptId == null ? '' : ' AND id <> ?'}',
      whereArgs: [name.trim(), ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Write methods take the executor so the repository can wrap the row write
  /// and its outbox entry in one transaction.
  Future<void> upsert(DatabaseExecutor txn, Supplier supplier) async {
    await txn.insert(
      DbTables.supplier,
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDelete(DatabaseExecutor txn, String id, int updatedAt) async {
    await txn.update(
      DbTables.supplier,
      {
        SyncColumns.isDeleted: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.syncStatus: 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// True when the supplier has any document against them. Nothing with history
  /// is deleted — the UI deactivates instead.
  Future<bool> hasTransactions(String id) async {
    final result = await _db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM ${DbTables.purchase}
           WHERE supplier_id = ? AND is_deleted = 0) +
        (SELECT COUNT(*) FROM ${DbTables.supplierPayment}
           WHERE supplier_id = ? AND is_deleted = 0) AS c
    ''', [id, id]);
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }
}
