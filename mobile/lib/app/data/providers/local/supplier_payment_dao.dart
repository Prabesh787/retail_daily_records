import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/domain/money.dart';
import '../../enums/payment_status.dart';
import '../../enums/supplier_payment_mode.dart';
import '../../models/supplier_payment.dart';

class SupplierPaymentDao {
  const SupplierPaymentDao(this._db);

  final Database _db;

  static final String _issued = PaymentStatus.issued.value;
  static final String _cancelled = PaymentStatus.cancelled.value;
  static final String _chequeMode = SupplierPaymentMode.cheque.value;

  static String get _select => '''
    SELECT sp.*,
      s.name    AS supplier_name,
      p.bill_no AS purchase_bill_no
    FROM ${DbTables.supplierPayment} sp
    LEFT JOIN ${DbTables.supplier} s ON s.id = sp.supplier_id
    LEFT JOIN ${DbTables.purchase} p ON p.id = sp.purchase_id
  ''';

  Future<List<SupplierPayment>> all({
    String? supplierId,
    String? purchaseId,
    String? fiscalYearId,
    PaymentStatus? status,
    int? fromMs,
    int? toMs,
    String? search,
    int? limit,
  }) async {
    final where = <String>['sp.is_deleted = 0'];
    final args = <Object?>[];

    if (supplierId != null) {
      where.add('sp.supplier_id = ?');
      args.add(supplierId);
    }
    if (purchaseId != null) {
      where.add('sp.purchase_id = ?');
      args.add(purchaseId);
    }
    if (fiscalYearId != null) {
      where.add('sp.fiscal_year_id = ?');
      args.add(fiscalYearId);
    }
    if (status != null) {
      where.add('sp.status = ?');
      args.add(status.value);
    }
    if (fromMs != null) {
      where.add('sp.payment_date >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('sp.payment_date <= ?');
      args.add(toMs);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add(
        '(sp.voucher_no LIKE ? OR sp.cheque_no LIKE ? OR '
        'sp.reference_no LIKE ? OR s.name LIKE ?)',
      );
      final term = '%${search.trim()}%';
      args..add(term)..add(term)..add(term)..add(term);
    }

    final rows = await _db.rawQuery('''
      $_select WHERE ${where.join(' AND ')}
      ORDER BY sp.payment_date DESC, sp.created_at DESC
      ${limit == null ? '' : 'LIMIT $limit'}
    ''', args);
    return rows.map(SupplierPayment.fromMap).toList();
  }

  Future<SupplierPayment?> byId(String id) async {
    final rows = await _db.rawQuery(
      '$_select WHERE sp.id = ? AND sp.is_deleted = 0 LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : SupplierPayment.fromMap(rows.first);
  }

  /// Cheques ordered by the date written on them, which is the order the money
  /// has to be available in — not the order they were handed over.
  ///
  /// [onlyPending] leaves out cheques that have already cleared or been
  /// cancelled, which is what the register shows by default: a cheque that has
  /// gone through is no longer something to plan around.
  Future<List<SupplierPayment>> chequeRegister({
    bool onlyPending = true,
    int? fromMs,
    int? toMs,
    int? limit,
  }) async {
    final where = <String>[
      'sp.is_deleted = 0',
      "sp.payment_mode = '$_chequeMode'",
    ];
    final args = <Object?>[];

    if (onlyPending) where.add("sp.status = '$_issued'");
    if (fromMs != null) {
      where.add('COALESCE(sp.cheque_date, sp.payment_date) >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('COALESCE(sp.cheque_date, sp.payment_date) <= ?');
      args.add(toMs);
    }

    final rows = await _db.rawQuery('''
      $_select WHERE ${where.join(' AND ')}
      ORDER BY COALESCE(sp.cheque_date, sp.payment_date) ASC
      ${limit == null ? '' : 'LIMIT $limit'}
    ''', args);
    return rows.map(SupplierPayment.fromMap).toList();
  }

  /// Money promised but still sitting in the account.
  Future<({Money total, int count})> uncleared() async {
    final row = (await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total, COUNT(*) AS cnt
      FROM ${DbTables.supplierPayment}
      WHERE is_deleted = 0 AND status = '$_issued'
    '''))
        .first;

    return (
      total: Money.fromColumn(row['total']),
      count: (row['cnt'] as int?) ?? 0,
    );
  }

  /// Paid out in a window. Cancelled payments are excluded — they settled
  /// nothing and never left the account.
  Future<({Money total, int count})> totalBetween(int fromMs, int toMs) async {
    final row = (await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total, COUNT(*) AS cnt
      FROM ${DbTables.supplierPayment}
      WHERE is_deleted = 0 AND status <> '$_cancelled'
        AND payment_date >= ? AND payment_date <= ?
    ''', [fromMs, toMs]))
        .first;

    return (
      total: Money.fromColumn(row['total']),
      count: (row['cnt'] as int?) ?? 0,
    );
  }

  Future<bool> voucherNoExists({
    required String fiscalYearId,
    required String voucherNo,
    String? exceptId,
  }) async {
    final rows = await _db.query(
      DbTables.supplierPayment,
      columns: ['id'],
      where: 'fiscal_year_id = ? AND voucher_no = ? AND is_deleted = 0'
          '${exceptId == null ? '' : ' AND id <> ?'}',
      whereArgs: [fiscalYearId, voucherNo, ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsert(DatabaseExecutor txn, SupplierPayment payment) async {
    await txn.insert(
      DbTables.supplierPayment,
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDelete(DatabaseExecutor txn, String id, int updatedAt) async {
    await txn.update(
      DbTables.supplierPayment,
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
