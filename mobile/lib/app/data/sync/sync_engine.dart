import 'dart:developer' as developer;

import '../dto/wire_codec.dart';
import '../providers/local/sync_queue_dao.dart';
import '../providers/remote/sync_api.dart';
import 'conflict_resolver.dart';
import 'entity_syncer.dart';
import 'sync_models.dart';

/// Where pull cursors live between runs. [StorageService] implements it, so
/// the engine never imports the service layer.
abstract class SyncCursorStore {
  String? cursorFor(String entity);
  void setCursor(String entity, String? cursor);
  int? get lastSyncedAt;
  set lastSyncedAt(int? value);
}

/// Push, then pull. Nothing else.
///
/// Push first so that local work is on the server before remote changes come
/// down; pulling first would resolve conflicts against a server that has not
/// yet heard this device's side of the story.
///
/// The engine never touches the UI and the UI never awaits the engine — the
/// user's save completed the moment SQLite committed.
class SyncEngine {
  SyncEngine({
    required this.api,
    required this.queue,
    required this.syncers,
    required this.cursors,
    required this.resolver,
    this.batchSize = 50,
    this.pullPageLimit = 200,
    this.onEntityChanged,
  });

  final SyncApi api;
  final SyncQueueDao queue;
  final List<EntitySyncer> syncers;
  final SyncCursorStore cursors;
  final ConflictResolver resolver;
  final int batchSize;
  final int pullPageLimit;

  /// Called with an entity name once a pull has actually landed rows for it.
  ///
  /// A callback rather than a direct dependency on the change bus: the engine
  /// is constructed with everything it needs and knows nothing about GetX,
  /// which is what lets the sync tests run it without a service graph.
  final void Function(String entity)? onEntityChanged;

  bool _running = false;
  bool get isRunning => _running;

  Future<SyncReport> sync() async {
    if (_running) {
      return const SyncReport(error: 'A sync is already running');
    }
    if (!api.isConfigured) {
      return const SyncReport(error: 'No backend configured');
    }

    _running = true;
    try {
      var report = await _push();
      if (report.error == null) {
        report = report.merge(await _pull());
      }
      final finishedAt = DateTime.now().millisecondsSinceEpoch;
      if (report.isSuccess) cursors.lastSyncedAt = finishedAt;
      return SyncReport(
        pushed: report.pushed,
        pulled: report.pulled,
        conflicts: report.conflicts,
        failed: report.failed,
        error: report.error,
        finishedAt: finishedAt,
      );
    } finally {
      _running = false;
    }
  }

  // ---- Push ---------------------------------------------------------------

  Future<SyncReport> _push() async {
    var pushed = 0;
    var conflicts = 0;
    var failed = 0;

    while (true) {
      final ops = await queue.pending(limit: batchSize);
      if (ops.isEmpty) break;

      final PushResult result;
      try {
        result = await api.push(ops);
      } catch (e) {
        // Transport failure: the whole batch stays queued and each row takes a
        // retry. Nothing is lost, and the next attempt starts where this left
        // off.
        for (final op in ops) {
          await queue.markFailed(op.queueId, e.toString());
        }
        return SyncReport(pushed: pushed, failed: ops.length, error: '$e');
      }

      final drained = <int>[];
      final matched = _matchResults(ops, result.results);

      for (final entry in matched.entries) {
        final op = entry.key;
        final res = entry.value;

        if (res == null) {
          // The server said nothing about this operation. Leave it queued
          // rather than assume success.
          await queue.markFailed(op.queueId, 'No result returned');
          failed++;
          continue;
        }

        switch (res.status) {
          case OperationStatus.accepted:
            await _syncerFor(op.entity)?.markSynced(op.entityId, op.updatedAt);
            drained.add(op.queueId);
            pushed++;

          case OperationStatus.conflict:
            conflicts++;
            final handled = await _applyConflict(op, res);
            if (handled) {
              drained.add(op.queueId);
            } else {
              await queue.markFailed(op.queueId, 'Conflict: ${res.message}');
            }

          case OperationStatus.error:
            failed++;
            await queue.markFailed(
              op.queueId,
              res.message ?? 'Rejected by server',
            );
            _log('push rejected ${op.entity}/${op.entityId}: ${res.message}');
        }
      }

      await queue.removeAll(drained);

      // Nothing drained means every row in this batch is stuck. Stop instead of
      // spinning on the same rows forever; their retry counters will retire
      // them and the next sync moves on to what is behind them.
      if (drained.isEmpty) break;
    }

    return SyncReport(pushed: pushed, conflicts: conflicts, failed: failed);
  }

  /// The server's result for a conflicting push. Returns true when the local
  /// operation can be dropped.
  Future<bool> _applyConflict(SyncOperation op, OperationResult res) async {
    final serverRow = res.serverRow;
    final syncer = _syncerFor(op.entity);
    if (serverRow == null || syncer == null) return false;

    final outcome = resolver.resolve(
      localUpdatedAt: await syncer.localUpdatedAt(op.entityId),
      remoteUpdatedAt: WireCodec.millis(serverRow['updated_at']),
      localIsPending: true,
      remoteDeviceId: WireCodec.stringOrNull(serverRow['device_id']),
    );

    if (outcome == ConflictOutcome.applyRemote) {
      await syncer.applyRemote(serverRow);
      return true;
    }
    // Ours is newer: keep the operation queued so the next push wins.
    return false;
  }

  /// Pairs operations with their results. Positional when the server returns
  /// one result per operation (the contract), falling back to matching by id.
  Map<SyncOperation, OperationResult?> _matchResults(
    List<SyncOperation> ops,
    List<OperationResult> results,
  ) {
    if (results.length == ops.length) {
      return {for (var i = 0; i < ops.length; i++) ops[i]: results[i]};
    }
    final byId = <String, OperationResult>{
      for (final r in results) r.entityId: r,
    };
    return {for (final op in ops) op: byId[op.entityId]};
  }

  // ---- Pull ---------------------------------------------------------------

  Future<SyncReport> _pull() async {
    var pulled = 0;

    for (final syncer in syncers) {
      var cursor = cursors.cursorFor(syncer.entity);
      var pages = 0;
      var applied = 0;

      while (true) {
        final PullResult page;
        try {
          page = await api.pull(
            entity: syncer.entity,
            cursor: cursor,
            limit: pullPageLimit,
          );
        } catch (e) {
          return SyncReport(pulled: pulled, error: '$e');
        }

        for (final row in page.rows) {
          if (await _applyRow(syncer, row)) {
            pulled++;
            applied++;
          }
        }

        // Advance only after the page is applied, so a crash mid-page replays
        // it rather than skipping it. Rows are upserts, so replaying is safe.
        cursor = page.nextCursor ?? cursor;
        cursors.setCursor(syncer.entity, cursor);

        pages++;
        if (!page.hasMore || page.isEmpty || pages >= 50) break;
      }

      // Once per entity rather than per row: a screen has no use for two
      // hundred reloads of the same list.
      if (applied > 0) onEntityChanged?.call(syncer.entity);
    }

    return SyncReport(pulled: pulled);
  }

  Future<bool> _applyRow(
    EntitySyncer syncer,
    Map<String, dynamic> row,
  ) async {
    final id = WireCodec.stringOrNull(row['id']);
    if (id == null) return false;

    final outcome = resolver.resolve(
      localUpdatedAt: await syncer.localUpdatedAt(id),
      remoteUpdatedAt: WireCodec.millis(row['updated_at']),
      localIsPending: await syncer.localIsPending(id),
      remoteDeviceId: WireCodec.stringOrNull(row['device_id']),
    );

    if (outcome != ConflictOutcome.applyRemote) return false;

    try {
      await syncer.applyRemote(row);
      return true;
    } catch (e) {
      // One malformed row must not abort the whole pull.
      _log('failed to apply ${syncer.entity}/$id: $e');
      return false;
    }
  }

  EntitySyncer? _syncerFor(String entity) {
    for (final s in syncers) {
      if (s.entity == entity) return s;
    }
    return null;
  }

  void _log(String message) =>
      developer.log(message, name: 'SyncEngine');
}
