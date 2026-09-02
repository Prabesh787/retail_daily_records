import '../../sync/sync_models.dart';
import 'api_client.dart';
import 'sync_api.dart';

/// The adapter to write once the backend team publishes their endpoints.
///
/// Contract handed to them (implementable on any database):
///
///   POST /sync/push
///     { "device_id": "...", "operations": [ { entity, entity_id,
///       operation, updated_at, payload } ] }
///     -> { "server_time": 0, "results": [ { entity_id, status:
///          accepted|conflict|error, server_row?, message? } ] }
///
///   `GET /sync/pull?entity=bills&cursor=<opaque>&limit=200`
///     -> { "rows": [...], "next_cursor": "...", "has_more": false,
///          "server_time": 0 }
///
/// Four things the server must honour:
///   1. Accept client-generated UUIDs as primary keys (never reassign ids).
///   2. Upsert by that id, idempotently — a retried push must not duplicate.
///   3. Soft-delete only; deleted rows still come back in pull as tombstones.
///   4. Return rows ordered by updated_at, and echo an opaque next_cursor.
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
    return PushResult.fromJson(json);
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
    return PullResult.fromJson(json);
  }
}
