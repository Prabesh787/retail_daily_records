import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../models/customer.dart';

class CustomerDao {
  const CustomerDao(this._db);

  final Database _db;

  /// Customers with their invoice count and total joined in, matching what the
  /// web's `/customers` endpoint returns. One grouped subquery, so the list
  /// costs the same whether there are five customers or five hundred.
  static String get _withTotals => '''
    SELECT c.*,
      COALESCE(s.cnt, 0)   AS sale_count,
      COALESCE(s.total, 0) AS sale_total
    FROM ${DbTables.customer} c
    LEFT JOIN (
      SELECT customer_id, COUNT(*) AS cnt, SUM(total_amount) AS total
      FROM ${DbTables.sale}
      WHERE is_deleted = 0 AND customer_id IS NOT NULL
      GROUP BY customer_id
    ) s ON s.customer_id = c.id
  ''';

  Future<List<Customer>> all({String? search, int? limit}) async {
    final where = <String>['c.is_deleted = 0'];
    final args = <Object?>[];

    if (search != null && search.trim().isNotEmpty) {
      where.add('(c.name LIKE ? OR c.phone LIKE ?)');
      final term = '%${search.trim()}%';
      args..add(term)..add(term);
    }

    final rows = await _db.rawQuery('''
      $_withTotals WHERE ${where.join(' AND ')}
      ORDER BY c.name COLLATE NOCASE ASC
      ${limit == null ? '' : 'LIMIT $limit'}
    ''', args);
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> byId(String id) async {
    final rows = await _db.rawQuery(
      '$_withTotals WHERE c.id = ? AND c.is_deleted = 0 LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<int> count() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DbTables.customer} WHERE is_deleted = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> upsert(DatabaseExecutor txn, Customer customer) async {
    await txn.insert(
      DbTables.customer,
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDelete(DatabaseExecutor txn, String id, int updatedAt) async {
    await txn.update(
      DbTables.customer,
      {
        SyncColumns.isDeleted: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.syncStatus: 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> hasSales(String id) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DbTables.sale} '
      'WHERE customer_id = ? AND is_deleted = 0',
      [id],
    );
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }
}
