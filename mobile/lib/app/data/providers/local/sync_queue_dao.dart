import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../enums/sync_status.dart';
import '../../sync/sync_models.dart';

/// The outbox.
///
/// Every write that must reach the server appends a row here **inside the same
/// transaction as the data write**. That is the whole durability guarantee: a
/// crash can never leave a saved bill that nobody remembers to push.
///
/// Rows are drained FIFO so a bill is pushed before the payment that settles
/// it, and a failed row keeps its place rather than being dropped.
class SyncQueueDao {
  const SyncQueueDao(this._db);

  final Database _db;

  /// Give up after this many attempts and mark the row failed, so one bad
  /// payload cannot block every later change behind it forever.
  static const int maxRetries = 5;

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.syncQueue} (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      entity      TEXT NOT NULL,
      entity_id   TEXT NOT NULL,
      operation   TEXT NOT NULL,
      updated_at  INTEGER NOT NULL,
      payload     TEXT NOT NULL,
      created_at  INTEGER NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0,
      last_error  TEXT
    )
  ''';

  /// Enqueue within a caller-supplied transaction. Pass the [txn] from the
  /// repository so the data row and the queue row commit together.
  static Future<void> enqueueIn(
    DatabaseExecutor txn, {
    required String entity,
    required String entityId,
    required SyncOperationType operation,
    required int updatedAt,
    required Map<String, dynamic> payload,
  }) async {
    final op = SyncOperation(
      queueId: 0,
      entity: entity,
      entityId: entityId,
      operation: operation,
      updatedAt: updatedAt,
      payload: payload,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await txn.insert(DbTables.syncQueue, op.toMap());
  }

  Future<List<SyncOperation>> pending({int limit = 100}) async {
    final rows = await _db.query(
      DbTables.syncQueue,
      where: 'retry_count < ?',
      whereArgs: [maxRetries],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
    return rows.map(SyncOperation.fromMap).toList();
  }

  /// Only counts rows still worth retrying — that is what the "N pending"
  /// chip should show. Permanently failed rows are surfaced separately.
  Future<int> pendingCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DbTables.syncQueue} WHERE retry_count < ?',
      [maxRetries],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> failedCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DbTables.syncQueue} WHERE retry_count >= ?',
      [maxRetries],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> remove(int queueId) async {
    await _db.delete(DbTables.syncQueue, where: 'id = ?', whereArgs: [queueId]);
  }

  Future<void> removeAll(Iterable<int> queueIds) async {
    if (queueIds.isEmpty) return;
    final placeholders = List.filled(queueIds.length, '?').join(',');
    await _db.delete(
      DbTables.syncQueue,
      where: 'id IN ($placeholders)',
      whereArgs: queueIds.toList(),
    );
  }

  Future<void> markFailed(int queueId, String error) async {
    await _db.rawUpdate(
      'UPDATE ${DbTables.syncQueue} '
      'SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, queueId],
    );
  }

  /// Clears the retry counter so the user's "try again" actually retries rows
  /// that had exhausted their attempts.
  Future<void> resetRetries() async {
    await _db.update(
      DbTables.syncQueue,
      {'retry_count': 0, 'last_error': null},
    );
  }

  Future<void> clear() async => _db.delete(DbTables.syncQueue);
}
