import 'package:sqflite/sqflite.dart';

import '../../../core/constants/db_constants.dart';
import '../../enums/document_type.dart';
import '../../enums/sync_status.dart';
import '../../models/attachment.dart';

class AttachmentDao {
  const AttachmentDao(this._db);

  final Database _db;

  /// The table each kind of parent lives in, for the "has it synced" join.
  static const Map<AttachmentEntityType, String> parentTables = {
    AttachmentEntityType.purchase: DbTables.purchase,
    AttachmentEntityType.supplierPayment: DbTables.supplierPayment,
    AttachmentEntityType.sale: DbTables.sale,
  };

  /// Oldest first, so scans read in the order they were taken.
  Future<List<Attachment>> forEntity(
    AttachmentEntityType type,
    String entityId,
  ) async {
    final rows = await _db.query(
      DbTables.attachment,
      where: 'entity_type = ? AND entity_id = ? AND is_deleted = 0',
      whereArgs: [type.value, entityId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  Future<Attachment?> byId(String id) async {
    final rows = await _db.query(
      DbTables.attachment,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Attachment.fromMap(rows.first);
  }

  Future<void> insert(Attachment attachment) =>
      _db.insert(DbTables.attachment, attachment.toMap());

  /// Scans the server can now accept: not uploaded yet, and the record they
  /// hang off has itself been synced. Uploading before that would be refused
  /// with a 404 for the parent.
  Future<List<Attachment>> awaitingUpload() async {
    final result = <Attachment>[];
    for (final entry in parentTables.entries) {
      final rows = await _db.rawQuery(
        '''
        SELECT a.* FROM ${DbTables.attachment} a
        JOIN ${entry.value} p ON p.id = a.entity_id
        WHERE a.entity_type = ?
          AND a.remote_id IS NULL
          AND a.is_deleted = 0
          AND p.${SyncColumns.syncStatus} = ?
        ORDER BY a.created_at ASC
        ''',
        [entry.key.value, SyncStatus.synced.code],
      );
      result.addAll(rows.map(Attachment.fromMap));
    }
    return result;
  }

  /// Removed on this device while the server still holds a copy.
  Future<List<Attachment>> awaitingRemoteDelete() async {
    final rows = await _db.query(
      DbTables.attachment,
      where: 'is_deleted = 1 AND remote_id IS NOT NULL',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  Future<void> markUploaded(String id, String remoteId) => _db.update(
    DbTables.attachment,
    {'remote_id': remoteId, 'upload_error': null},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> markUploadFailed(String id, String message) => _db.update(
    DbTables.attachment,
    {'upload_error': message},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> markDeleted(String id) => _db.update(
    DbTables.attachment,
    {'is_deleted': 1},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> purge(String id) =>
      _db.delete(DbTables.attachment, where: 'id = ?', whereArgs: [id]);
}
