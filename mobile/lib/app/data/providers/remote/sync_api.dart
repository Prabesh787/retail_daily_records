import '../../sync/sync_models.dart';

/// The entire surface the app needs from a backend.
///
/// Everything above this line is written once. Whether the server ends up on
/// Postgres, MySQL or Mongo is invisible here — only the JSON contract matters,
/// so a backend decision that has not been made yet cannot block the app.
abstract class SyncApi {
  /// False until a real endpoint is wired; the UI then shows "Local only"
  /// instead of pretending a sync is pending.
  bool get isConfigured;

  /// Send queued changes, oldest first. Must be idempotent on the server: a
  /// retry after a timeout has to update the same row, not create a duplicate.
  Future<PushResult> push(List<SyncOperation> operations);

  /// Fetch rows for [entity] changed since [cursor], tombstones included.
  Future<PullResult> pull({
    required String entity,
    String? cursor,
    int limit = 200,
  });
}

/// Default implementation: the app is fully usable, nothing leaves the device.
/// Swapped for [RestSyncApi] in one line of [InitialBinding] once the backend
/// team publishes their endpoints.
class NoopSyncApi implements SyncApi {
  const NoopSyncApi();

  @override
  bool get isConfigured => false;

  @override
  Future<PushResult> push(List<SyncOperation> operations) async =>
      const PushResult();

  @override
  Future<PullResult> pull({
    required String entity,
    String? cursor,
    int limit = 200,
  }) async =>
      const PullResult();
}
