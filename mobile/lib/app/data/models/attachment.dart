import '../../core/constants/db_constants.dart';
import '../enums/document_type.dart';
import 'base/syncable_model.dart';

/// A scan of the paper behind a record — the wholesaler's bill, a payment
/// receipt, a cheque copy.
///
/// Not a [SyncableModel], and it never goes through the sync queue. The bytes
/// travel as a multipart upload to `POST /attachments`, which the server only
/// accepts once the record it hangs off exists there. So a scan is kept on the
/// device first, where it is useful the moment it is taken, and the uploader
/// sends it after its parent has synced. [remoteId] is the server's id once
/// that has happened.
class Attachment {
  const Attachment({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.documentType,
    required this.fileName,
    required this.originalFileName,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
    this.remoteId,
    this.uploadError,
    this.isDeleted = false,
  });

  final String id;
  final AttachmentEntityType entityType;
  final String entityId;
  final DocumentType documentType;

  /// Name of the copy inside the app's attachments folder — a name rather than
  /// a path, because the folder's absolute path is not stable across app
  /// updates on iOS.
  final String fileName;

  final String originalFileName;
  final String mimeType;

  /// Bytes.
  final int fileSize;

  final int createdAt;

  /// The server's id for this file. Null until uploaded.
  final String? remoteId;

  /// Why the last upload attempt was refused, if it was.
  final String? uploadError;

  /// Removed here, but the server still holds a copy that has to be deleted.
  /// Rows that were never uploaded are removed outright instead.
  final bool isDeleted;

  bool get isUploaded => remoteId != null;

  bool get isImage => mimeType.startsWith('image/');

  Map<String, dynamic> toMap() => {
    'id': id,
    'entity_type': entityType.value,
    'entity_id': entityId,
    'document_type': documentType.value,
    'file_name': fileName,
    'original_file_name': originalFileName,
    'mime_type': mimeType,
    'file_size': fileSize,
    'remote_id': remoteId,
    'upload_error': uploadError,
    'is_deleted': isDeleted ? 1 : 0,
    'created_at': createdAt,
  };

  factory Attachment.fromMap(Map<String, dynamic> map) => Attachment(
    id: map['id'] as String,
    entityType: AttachmentEntityType.fromValue(map['entity_type'] as String?),
    entityId: (map['entity_id'] as String?) ?? '',
    documentType: DocumentType.fromValue(map['document_type'] as String?),
    fileName: (map['file_name'] as String?) ?? '',
    originalFileName: (map['original_file_name'] as String?) ?? '',
    mimeType: (map['mime_type'] as String?) ?? 'application/octet-stream',
    fileSize: SyncableModel.toInt(map['file_size']),
    createdAt: SyncableModel.toInt(map['created_at']),
    remoteId: map['remote_id'] as String?,
    uploadError: map['upload_error'] as String?,
    isDeleted: SyncableModel.toInt(map['is_deleted']) == 1,
  );

  /// No foreign key: the parent is one of several tables.
  static const String createTableSql =
      '''
    CREATE TABLE IF NOT EXISTS ${DbTables.attachment} (
      id                 TEXT PRIMARY KEY,
      entity_type        TEXT NOT NULL,
      entity_id          TEXT NOT NULL,
      document_type      TEXT NOT NULL,
      file_name          TEXT NOT NULL,
      original_file_name TEXT NOT NULL,
      mime_type          TEXT NOT NULL,
      file_size          INTEGER NOT NULL DEFAULT 0,
      remote_id          TEXT,
      upload_error       TEXT,
      is_deleted         INTEGER NOT NULL DEFAULT 0,
      created_at         INTEGER NOT NULL
    )
  ''';

  static const String entityIndexSql =
      '''
    CREATE INDEX IF NOT EXISTS idx_attachment_entity
      ON ${DbTables.attachment} (entity_type, entity_id)
  ''';
}
