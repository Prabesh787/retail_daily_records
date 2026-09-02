import '../../enums/sync_status.dart';
import '../../sync/sync_models.dart';
import 'sync_api.dart';

/// An in-memory server.
///
/// This is the reason the undecided backend does not block anything: the whole
/// sync engine, the retry path, the pending-count chip and the merge rules can
/// be built and tested today against this, then the real adapter drops in
/// without a line changing above the [SyncApi] boundary.
///
/// It deliberately behaves like a slightly hostile server — configurable
/// latency, failures and conflicts — because a fake that always succeeds only
/// proves the happy path works.
class FakeSyncApi implements SyncApi {
  FakeSyncApi({
    this.latency = const Duration(milliseconds: 400),
    this.failEveryNthPush = 0,
    this.conflictEntityIds = const {},
  });

  final Duration latency;

  /// Set to e.g. 3 to fail every third push and exercise the retry path.
  final int failEveryNthPush;

  /// Ids the fake server claims to have a newer version of.
  final Set<String> conflictEntityIds;

  /// entity -> (entityId -> row)
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};
  int _pushCount = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<PushResult> push(List<SyncOperation> operations) async {
    await Future<void>.delayed(latency);
    _pushCount++;
    if (failEveryNthPush > 0 && _pushCount % failEveryNthPush == 0) {
      throw Exception('FakeSyncApi: simulated push failure');
    }

    final results = <OperationResult>[];
    for (final op in operations) {
      if (conflictEntityIds.contains(op.entityId)) {
        results.add(
          OperationResult(
            entityId: op.entityId,
            status: OperationStatus.conflict,
            serverRow: _store[op.entity]?[op.entityId],
            message: 'Server has a newer version',
          ),
        );
        continue;
      }

      final table = _store.putIfAbsent(op.entity, () => {});
      if (op.operation == SyncOperationType.delete) {
        table[op.entityId] = {
          ...?table[op.entityId],
          ...op.payload,
          'is_deleted': true,
          'updated_at': op.updatedAt,
        };
      } else {
        table[op.entityId] = {...op.payload, 'updated_at': op.updatedAt};
      }
      results.add(
        OperationResult(
          entityId: op.entityId,
          status: OperationStatus.accepted,
        ),
      );
    }

    return PushResult(
      results: results,
      serverTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<PullResult> pull({
    required String entity,
    String? cursor,
    int limit = 200,
  }) async {
    await Future<void>.delayed(latency);
    final since = int.tryParse(cursor ?? '') ?? 0;

    final rows = (_store[entity]?.values ?? const <Map<String, dynamic>>[])
        .where((row) => ((row['updated_at'] as int?) ?? 0) > since)
        .toList()
      ..sort(
        (a, b) => ((a['updated_at'] as int?) ?? 0)
            .compareTo((b['updated_at'] as int?) ?? 0),
      );

    final page = rows.take(limit).toList();
    final next = page.isEmpty
        ? cursor
        : (page.last['updated_at'] as int?)?.toString() ?? cursor;

    return PullResult(
      rows: page,
      nextCursor: next,
      hasMore: rows.length > limit,
      serverTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// What the "server" holds for one entity — so a test can assert on the shape
  /// that actually went over the wire rather than on the model it came from.
  List<Map<String, dynamic>> storedFor(String entity) =>
      (_store[entity]?.values ?? const <Map<String, dynamic>>[]).toList();

  /// Test helper: pretend another device (or the web app) changed a row.
  void seedRemoteChange(String entity, Map<String, dynamic> row) {
    final id = row['id'] as String?;
    if (id == null) return;
    _store.putIfAbsent(entity, () => {})[id] = row;
  }

  void reset() {
    _store.clear();
    _pushCount = 0;
  }
}
