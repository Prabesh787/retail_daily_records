import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../models/fiscal_year.dart';

class FiscalYearDao {
  const FiscalYearDao(this._db);

  final Database _db;

  Future<List<FiscalYear>> all() async {
    final rows = await _db.query(
      DbTables.fiscalYear,
      where: 'is_deleted = 0',
      orderBy: 'start_date DESC',
    );
    return rows.map(FiscalYear.fromMap).toList();
  }

  Future<FiscalYear?> byId(String id) async {
    final rows = await _db.query(
      DbTables.fiscalYear,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : FiscalYear.fromMap(rows.first);
  }

  /// The year new records are filed under.
  ///
  /// Null before one has been created, which every form has to handle: there is
  /// nothing to record against yet.
  Future<FiscalYear?> active() async {
    final rows = await _db.query(
      DbTables.fiscalYear,
      where: 'is_active = 1 AND is_deleted = 0',
      orderBy: 'start_date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : FiscalYear.fromMap(rows.first);
  }

  /// The year a given date falls inside.
  ///
  /// A back-dated bill belongs to the year that contains its own date, not to
  /// whichever year happens to be active today — otherwise a bill written in
  /// Ashadh and entered in Shrawan lands in the wrong year's totals.
  Future<FiscalYear?> covering(int dateMs) async {
    final rows = await _db.query(
      DbTables.fiscalYear,
      where: 'start_date <= ? AND end_date >= ? AND is_deleted = 0',
      whereArgs: [dateMs, dateMs],
      limit: 1,
    );
    return rows.isEmpty ? null : FiscalYear.fromMap(rows.first);
  }

  Future<bool> nameExists(String name, {String? exceptId}) async {
    final rows = await _db.query(
      DbTables.fiscalYear,
      columns: ['id'],
      where:
          'name = ? AND is_deleted = 0${exceptId == null ? '' : ' AND id <> ?'}',
      whereArgs: [name, ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsert(DatabaseExecutor txn, FiscalYear year) async {
    await txn.insert(
      DbTables.fiscalYear,
      year.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The other years, so the repository can clear their active flag and queue
  /// each one for push.
  ///
  /// Postgres enforces "at most one active" with a partial unique index. SQLite
  /// has no equivalent that survives an out-of-order sync, so it is enforced in
  /// the repository instead — inside one transaction, so there is never a moment
  /// with two active years or none.
  Future<List<FiscalYear>> othersActive(
    DatabaseExecutor txn,
    String keepId,
  ) async {
    final rows = await txn.query(
      DbTables.fiscalYear,
      where: 'id <> ? AND is_active = 1 AND is_deleted = 0',
      whereArgs: [keepId],
    );
    return rows.map(FiscalYear.fromMap).toList();
  }

  Future<void> softDelete(DatabaseExecutor txn, String id, int updatedAt) async {
    await txn.update(
      DbTables.fiscalYear,
      {
        SyncColumns.isDeleted: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.syncStatus: 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// True when anything has been filed under this year. A year with documents
  /// refuses deletion — the same rule the server applies.
  Future<bool> hasTransactions(String id) async {
    final result = await _db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM ${DbTables.purchase}
           WHERE fiscal_year_id = ? AND is_deleted = 0) +
        (SELECT COUNT(*) FROM ${DbTables.supplierPayment}
           WHERE fiscal_year_id = ? AND is_deleted = 0) +
        (SELECT COUNT(*) FROM ${DbTables.sale}
           WHERE fiscal_year_id = ? AND is_deleted = 0) AS c
    ''', [id, id, id]);
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }
}
