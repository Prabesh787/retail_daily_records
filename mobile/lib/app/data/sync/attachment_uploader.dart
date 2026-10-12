import 'dart:developer' as developer;
import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../models/attachment.dart';
import '../providers/local/attachment_dao.dart';
import '../providers/remote/attachment_api.dart';

/// Sends scans to the server, and removes the ones deleted here.
///
/// Runs after a sync rather than inside it: an attachment can only be
/// uploaded once its bill is on the server, and the push that puts it there
/// is what a sync does first. Never blocks the user - a scan is fully usable
/// on the device whether or not it has gone up yet.
class AttachmentUploader {
  AttachmentUploader({
    required this.dao,
    required this.api,
    required this.fileFor,
  });

  final AttachmentDao dao;
  final AttachmentApi api;
  final Future<File> Function(Attachment attachment) fileFor;

  bool _running = false;

  /// How many rows changed state. Stops at the first failure worth retrying
  /// (no connection, a timeout, a 5xx, an expired token): every later request
  /// would fail the same way, and the next sync tries again.
  Future<int> run() async {
    if (_running || !api.isConfigured) return 0;
    _running = true;
    var changed = 0;

    try {
      for (final attachment in await dao.awaitingRemoteDelete()) {
        try {
          await api.delete(attachment.remoteId!);
        } on NetworkException catch (e) {
          // Already gone there is what we wanted.
          if (e.statusCode != 404) {
            if (_shouldStop(e)) return changed;
            _log('delete ${attachment.id} refused: ${e.message}');
            continue;
          }
        }
        await dao.purge(attachment.id);
        changed++;
      }

      for (final attachment in await dao.awaitingUpload()) {
        final file = await fileFor(attachment);
        if (!file.existsSync()) {
          await dao.markUploadFailed(attachment.id, 'File missing on device');
          continue;
        }

        try {
          final remoteId = await api.upload(
            entityType: attachment.entityType.value,
            entityId: attachment.entityId,
            documentType: attachment.documentType.value,
            filePath: file.path,
            fileName: attachment.originalFileName,
            mimeType: attachment.mimeType,
          );
          await dao.markUploaded(attachment.id, remoteId);
          changed++;
        } on NetworkException catch (e) {
          if (_shouldStop(e)) return changed;
          // Refused (too large, wrong type): record why and move on, so one
          // bad file does not hold up the rest.
          await dao.markUploadFailed(attachment.id, e.message);
          _log('upload ${attachment.id} refused: ${e.message}');
        } on FormatException catch (e) {
          await dao.markUploadFailed(attachment.id, e.message);
        }
      }
      return changed;
    } finally {
      _running = false;
    }
  }

  bool _shouldStop(NetworkException e) => e.isRetryable || e.statusCode == 401;

  void _log(String message) =>
      developer.log(message, name: 'AttachmentUploader');
}
