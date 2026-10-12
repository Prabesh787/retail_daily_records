import '../../sync/sync_models.dart';

/// The entire surface the app needs from a backend.
///
/// Everything above this line is written once. Whether the server keeps its
/// records in Postgres, MySQL or Mongo is invisible here — only the JSON
/// contract matters, which is what lets the app be built and used before, and
/// independently of, whatever is on the other end.
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

/// Used when the build has no server address: the app is fully usable and
/// nothing leaves the device. [InitialBinding] picks [RestSyncApi] instead as
/// soon as `API_BASE_URL` is set.
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
