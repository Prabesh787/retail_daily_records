import 'api_client.dart';

/// `POST /attachments` and `DELETE /attachments/:id`.
///
/// Separate from [SyncApi] because files do not fit the push/pull contract:
/// they are bytes, not rows, and they go up one multipart request each.
class AttachmentApi {
  const AttachmentApi(this._client);

  final ApiClient _client;

  static const String path = '/attachments';

  bool get isConfigured => _client.isConfigured;

  /// Returns the server's id for the stored file.
  Future<String> upload({
    required String entityType,
    required String entityId,
    required String documentType,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    final json = await _client.upload(
      path,
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      fields: {
        'entityType': entityType,
        'entityId': entityId,
        'documentType': documentType,
      },
    );
    final data = json['data'];
    final id = data is Map ? data['id'] : null;
    if (id is! String) {
      throw const FormatException('Upload response carried no attachment id');
    }
    return id;
  }

  Future<void> delete(String remoteId) => _client.delete('$path/$remoteId');
}
