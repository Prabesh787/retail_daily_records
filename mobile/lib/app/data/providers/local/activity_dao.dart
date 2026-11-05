import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../enums/payment_status.dart';
import '../../enums/sale_payment_mode.dart';
import '../../enums/supplier_payment_mode.dart';
import '../../models/ledger.dart';

/// Reads that span several documents: the History tab and the cheque
/// register. The documents stay in their own tables; these are views over them.
class ActivityDao {
  const ActivityDao(this._db);

  final Database _db;

  static final String _cancelled = PaymentStatus.cancelled.value;
  static final String _issued = PaymentStatus.issued.value;
  static final String _credit = SalePaymentMode.credit.value;
  static final String _cheque = SupplierPaymentMode.cheque.value;

  static String get _feedSql => '''
    SELECT 'sale' AS kind, s.id, s.sale_date AS date_ms, s.created_at,
      s.total_amount AS amount,
      COALESCE((
        SELECT SUM(sp.amount) FROM ${DbTables.salePayment} sp
        WHERE sp.sale_id = s.id AND sp.payment_mode <> '$_credit'
          AND sp.status <> '$_cancelled'
      ), 0) + COALESCE((
        SELECT SUM(cp.amount) FROM ${DbTables.customerPayment} cp
        WHERE cp.sale_id = s.id AND cp.is_deleted = 0
          AND cp.status <> '$_cancelled'
      ), 0) AS paid,
      c.name AS party_name, s.invoice_no AS doc_no,
      (
        SELECT sp.payment_mode FROM ${DbTables.salePayment} sp
        WHERE sp.sale_id = s.id ORDER BY sp.created_at ASC LIMIT 1
      ) AS mode,
      NULL AS status
    FROM ${DbTables.sale} s
    LEFT JOIN ${DbTables.customer} c ON c.id = s.customer_id
    WHERE s.is_deleted = 0

    UNION ALL
    SELECT 'purchase', p.id, p.bill_date, p.created_at, p.amount,
      COALESCE((
        SELECT SUM(sup.amount) FROM ${DbTables.supplierPayment} sup
        WHERE sup.purchase_id = p.id AND sup.is_deleted = 0
          AND sup.status <> '$_cancelled'
      ), 0),
      s.name, p.bill_no, NULL, NULL
    FROM ${DbTables.purchase} p
    LEFT JOIN ${DbTables.supplier} s ON s.id = p.supplier_id
    WHERE p.is_deleted = 0

    UNION ALL
    SELECT 'paymentIn', cp.id, cp.payment_date, cp.created_at, cp.amount, 0,
      c.name, COALESCE(cp.cheque_no, cp.voucher_no), cp.payment_mode, cp.status
    FROM ${DbTables.customerPayment} cp
    LEFT JOIN ${DbTables.customer} c ON c.id = cp.customer_id
    WHERE cp.is_deleted = 0

    UNION ALL
    SELECT 'paymentOut', sup.id, sup.payment_date, sup.created_at, sup.amount, 0,
      s.name, COALESCE(sup.cheque_no, sup.voucher_no), sup.payment_mode, sup.status
    FROM ${DbTables.supplierPayment} sup
    LEFT JOIN ${DbTables.supplier} s ON s.id = sup.supplier_id
    WHERE sup.is_deleted = 0
  ''';

  Future<List<ActivityItem>> feed({
    ActivityKind? kind,
    String? search,
    int? fromMs,
    int? toMs,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (kind != null) {
      where.add('kind = ?');
      args.add(kind.name);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(party_name LIKE ? OR doc_no LIKE ?)');
      final term = '%${search.trim()}%';
      args..add(term)..add(term);
    }
    if (fromMs != null) {
      where.add('date_ms >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('date_ms <= ?');
      args.add(toMs);
    }

    final rows = await _db.rawQuery('''
      SELECT * FROM ($_feedSql)
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY date_ms DESC, created_at DESC
      ${limit == null ? '' : 'LIMIT $limit'}
    ''', args);
    return rows.map(ActivityItem.fromMap).toList();
  }

  /// Every cheque the shop has received or written, soonest date first.
  Future<List<ChequeItem>> cheques({bool onlyPending = true}) async {
    final rows = await _db.rawQuery('''
      SELECT * FROM (
        SELECT 'saleLine' AS source, sp.id AS id, s.id AS parent_id, sp.amount AS amount,
          COALESCE(sp.cheque_date, s.sale_date) AS due_ms, s.sale_date AS issued_ms,
          sp.status AS status, COALESCE(c.name, 'Walk-in sale') AS party_name,
          sp.cheque_no AS cheque_no, sp.account_id AS account_id,
          a.name AS account_name, sp.cleared_date AS cleared_date
        FROM ${DbTables.salePayment} sp
        JOIN ${DbTables.sale} s ON s.id = sp.sale_id AND s.is_deleted = 0
        LEFT JOIN ${DbTables.customer} c ON c.id = s.customer_id
        LEFT JOIN ${DbTables.account} a ON a.id = sp.account_id
        WHERE sp.payment_mode = '$_cheque'

        UNION ALL
        SELECT 'customerPayment', cp.id, cp.id, cp.amount,
          COALESCE(cp.cheque_date, cp.payment_date), cp.payment_date, cp.status,
          c.name, cp.cheque_no, cp.account_id, a.name, cp.cleared_date
        FROM ${DbTables.customerPayment} cp
        LEFT JOIN ${DbTables.customer} c ON c.id = cp.customer_id
        LEFT JOIN ${DbTables.account} a ON a.id = cp.account_id
        WHERE cp.is_deleted = 0 AND cp.payment_mode = '$_cheque'

        UNION ALL
        SELECT 'supplierPayment', sup.id, sup.id, sup.amount,
          COALESCE(sup.cheque_date, sup.payment_date), sup.payment_date, sup.status,
          s.name, sup.cheque_no, sup.account_id, a.name, sup.cleared_date
        FROM ${DbTables.supplierPayment} sup
        LEFT JOIN ${DbTables.supplier} s ON s.id = sup.supplier_id
        LEFT JOIN ${DbTables.account} a ON a.id = sup.account_id
        WHERE sup.is_deleted = 0 AND sup.payment_mode = '$_cheque'
      )
      ${onlyPending ? "WHERE status = '$_issued'" : ''}
      ORDER BY due_ms ASC, issued_ms ASC
    ''');
    return rows.map(ChequeItem.fromMap).toList();
  }
}
