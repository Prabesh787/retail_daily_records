import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/db_constants.dart';
import '../../services/data_change_service.dart';
import '../../services/database_service.dart';
import '../enums/document_type.dart';
import '../models/attachment.dart';
import '../providers/local/attachment_dao.dart';

/// Scans of the paper behind a record, kept on the device.
///
/// Adding one copies the picked file into the app's own folder straight away.
/// The camera's or gallery's copy is not ours to rely on - a temp file the OS
/// clears, a photo the shopkeeper later deletes from their gallery - and the
/// scan has to outlive both, since it is the evidence for the bill.
class AttachmentRepository {
  static const Uuid _uuid = Uuid();

  /// Folder under the app's documents directory.
  static const String folderName = 'attachments';

  AttachmentDao get _dao => Get.find<DatabaseService>().attachments;

  static Future<Directory> folder() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, folderName));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> fileFor(Attachment attachment) async =>
      File(p.join((await folder()).path, attachment.fileName));

  Future<List<Attachment>> forEntity(
    AttachmentEntityType type,
    String entityId,
  ) => _dao.forEntity(type, entityId);

  /// Copies [sourcePath] in and records it against the given record.
  Future<Attachment> add({
    required AttachmentEntityType entityType,
    required String entityId,
    required DocumentType documentType,
    required String sourcePath,
    String? originalFileName,
  }) async {
    final id = _uuid.v4();
    final extension = p.extension(sourcePath).toLowerCase();
    final fileName = '$id$extension';

    final copy = await File(
      sourcePath,
    ).copy(p.join((await folder()).path, fileName));

    final attachment = Attachment(
      id: id,
      entityType: entityType,
      entityId: entityId,
      documentType: documentType,
      fileName: fileName,
      originalFileName: originalFileName ?? p.basename(sourcePath),
      mimeType: mimeTypeFor(extension),
      fileSize: await copy.length(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await _dao.insert(attachment);
    } catch (_) {
      // No row means nothing would ever point at the copy again.
      await copy.delete().catchError((_) => copy);
      rethrow;
    }

    _announce();
    return attachment;
  }

  /// Removes the scan from this device.
  ///
  /// One the server never received is gone outright. One it did receive is
  /// marked deleted and left for the uploader to delete there too, so removing
  /// a scan works offline like every other change.
  Future<void> remove(Attachment attachment) async {
    if (attachment.isUploaded) {
      await _dao.markDeleted(attachment.id);
    } else {
      await _dao.purge(attachment.id);
    }

    final file = await fileFor(attachment);
    if (file.existsSync()) await file.delete();

    _announce();
  }

  /// What the server's upload filter expects for a given extension.
  static String mimeTypeFor(String extension) =>
      switch (extension.toLowerCase().replaceFirst('.', '')) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

  void _announce() {
    if (Get.isRegistered<DataChangeService>()) {
      Get.find<DataChangeService>().publish([DbTables.attachment]);
    }
  }
}
