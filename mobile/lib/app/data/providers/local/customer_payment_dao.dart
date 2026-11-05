import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../models/customer_payment.dart';

class CustomerPaymentDao {
  const CustomerPaymentDao(this._db);

  final Database _db;

  static String get _select => '''
    SELECT cp.*,
      c.name       AS customer_name,
      a.name       AS account_name,
      s.invoice_no AS sale_invoice_no
    FROM ${DbTables.customerPayment} cp
    LEFT JOIN ${DbTables.customer} c ON c.id = cp.customer_id
    LEFT JOIN ${DbTables.account} a ON a.id = cp.account_id
    LEFT JOIN ${DbTables.sale} s ON s.id = cp.sale_id
  ''';

  Future<List<CustomerPayment>> all({String? customerId, String? saleId}) async {
    final where = <String>['cp.is_deleted = 0'];
    final args = <Object?>[];

    if (customerId != null) {
      where.add('cp.customer_id = ?');
      args.add(customerId);
    }
    if (saleId != null) {
      where.add('cp.sale_id = ?');
      args.add(saleId);
    }

    final rows = await _db.rawQuery('''
      $_select WHERE ${where.join(' AND ')}
      ORDER BY cp.payment_date DESC, cp.created_at DESC
    ''', args);
    return rows.map(CustomerPayment.fromMap).toList();
  }

  Future<CustomerPayment?> byId(String id) async {
    final rows = await _db.rawQuery(
      '$_select WHERE cp.id = ? AND cp.is_deleted = 0 LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : CustomerPayment.fromMap(rows.first);
  }

  Future<bool> voucherNoExists({
    required String fiscalYearId,
    required String voucherNo,
  }) async {
    final rows = await _db.query(
      DbTables.customerPayment,
      columns: ['id'],
      where: 'fiscal_year_id = ? AND voucher_no = ? AND is_deleted = 0',
      whereArgs: [fiscalYearId, voucherNo],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsert(DatabaseExecutor txn, CustomerPayment payment) async {
    await txn.insert(
      DbTables.customerPayment,
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
