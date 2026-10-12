import '../../sync/sync_models.dart';
import 'api_client.dart';
import 'sync_api.dart';

/// The adapter onto the Express backend's `/sync` module.
///
/// The contract, which that module implements:
///
///   POST /sync/push
///     { "device_id": "...", "operations": [ { entity, entity_id,
///       operation, updated_at, payload } ] }
///     -> { "server_time": 0, "results": [ { entity_id, status:
///          accepted|conflict|error, server_row?, message? } ] }
///
///   `GET /sync/pull?entity=suppliers&cursor=<opaque>&limit=200`
///     -> { "rows": [...], "next_cursor": "...", "has_more": false,
///          "server_time": 0 }
///
/// Four things the server honours, and has to:
///   1. Client-generated UUIDs are the primary keys; ids are never reassigned.
///   2. Upsert by that id, idempotently — a retried push does not duplicate.
///   3. Deletions leave a tombstone, which comes back in pull as a row with
///      `is_deleted: true`.
///   4. Rows are ordered by their change time, with an opaque cursor echoed
///      back as `next_cursor`.
class RestSyncApi implements SyncApi {
  RestSyncApi(this._client, {this.deviceId});

  final ApiClient _client;
  final String? deviceId;

  static const String pushPath = '/sync/push';
  static const String pullPath = '/sync/pull';

  @override
  bool get isConfigured => _client.isConfigured;

  @override
  Future<PushResult> push(List<SyncOperation> operations) async {
    final json = await _client.post(
      pushPath,
      body: {
        'device_id': deviceId,
        'operations': operations.map((e) => e.toJson()).toList(),
      },
    );
    return PushResult.fromJson(_unwrap(json));
  }

  @override
  Future<PullResult> pull({
    required String entity,
    String? cursor,
    int limit = 200,
  }) async {
    final json = await _client.get(
      pullPath,
      query: {
        'entity': entity,
        'cursor': ?cursor,
        'limit': limit,
        'device_id': ?deviceId,
      },
    );
    return PullResult.fromJson(_unwrap(json));
  }

  /// The API wraps every response in `{ success, message, data }`, exactly as
  /// it does for auth. Unwrapping here keeps the envelope out of the sync
  /// models, which are written against the contract above and nothing else.
  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final data = json['data'];
    return data is Map<String, dynamic> ? data : json;
  }
}
