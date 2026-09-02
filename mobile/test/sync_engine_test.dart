import 'package:billrecord/app/data/enums/sync_status.dart';
import 'package:billrecord/app/data/providers/local/sync_queue_dao.dart';
import 'package:billrecord/app/data/providers/remote/fake_sync_api.dart';
import 'package:billrecord/app/data/providers/remote/sync_api.dart';
import 'package:billrecord/app/data/sync/conflict_resolver.dart';
import 'package:billrecord/app/data/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// The offline guarantees, tested against [FakeSyncApi] — which is exactly why
/// that fake exists: none of this needs a backend to be running.
///
/// These run against [TestEntity] rather than a real model on purpose. What is
/// under test is the engine — that a save is queued, that a failed push keeps
/// the change, that an older server row cannot overwrite a newer local edit —
/// and none of that has anything to do with what a supplier is. Tying these to
/// a domain model means they break whenever the domain changes, which is both
/// noisy and a good way to lose the coverage.
void main() {
  late Database db;
  late SyncQueueDao queue;
  late FakeSyncApi api;
  late FakeCursorStore cursors;
  late SyncEngine engine;

  const deviceId = 'device-a';
  const now = 1700000000000;

  SyncEngine buildEngine(SyncApi withApi) => SyncEngine(
        api: withApi,
        queue: queue,
        syncers: [TestEntitySyncer(db)],
        cursors: cursors,
        resolver: const ConflictResolver(deviceId: deviceId),
      );

  setUp(() async {
    db = await openTestDb();
    queue = SyncQueueDao(db);
    api = FakeSyncApi(latency: Duration.zero);
    cursors = FakeCursorStore();
    engine = buildEngine(api);
  });

  tearDown(() => db.close());

  Future<TestEntity?> read(String id) async {
    final rows = await db.query(
      TestEntity.table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TestEntity.fromMap(rows.first);
  }

  /// Mirrors what BaseRepository does: the row and its outbox entry commit in
  /// one transaction. That pairing is the whole offline guarantee — if the row
  /// exists, the change to push exists too.
  Future<TestEntity> saveLocally({
    String id = 'p1',
    String name = 'Ramesh',
    int updatedAt = now,
  }) async {
    final row = TestEntity(
      id: id,
      name: name,
      updatedAt: updatedAt,
      deviceId: deviceId,
    );
    await db.transaction((txn) async {
      await txn.insert(
        TestEntity.table,
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await SyncQueueDao.enqueueIn(
        txn,
        entity: TestEntity.table,
        entityId: row.id,
        operation: SyncOperationType.upsert,
        updatedAt: row.updatedAt,
        payload: row.toJson(),
      );
    });
    return row;
  }

  test('a local save is queued for push', () async {
    await saveLocally();
    expect(await queue.pendingCount(), 1);
  });

  test('a successful push drains the queue and marks the row synced', () async {
    await saveLocally();

    final report = await engine.sync();

    expect(report.pushed, 1);
    expect(report.isSuccess, isTrue);
    expect(await queue.pendingCount(), 0);
    expect((await read('p1'))!.syncStatus, SyncStatus.synced);
  });

  test('a failed push keeps the change queued instead of losing it', () async {
    engine = buildEngine(FakeSyncApi(latency: Duration.zero, failEveryNthPush: 1));

    await saveLocally();
    final report = await engine.sync();

    expect(report.isSuccess, isFalse);
    expect(
      await queue.pendingCount(),
      1,
      reason: 'the record must survive a network failure',
    );
    expect((await read('p1'))!.syncStatus, SyncStatus.pending);
  });

  test('retries stop after the limit so one bad row cannot block the rest',
      () async {
    engine = buildEngine(FakeSyncApi(latency: Duration.zero, failEveryNthPush: 1));
    await saveLocally();

    for (var i = 0; i < SyncQueueDao.maxRetries; i++) {
      await engine.sync();
    }

    // Retired rather than retried forever: the count of things still worth
    // sending drops to zero, and the failure is surfaced separately.
    expect(await queue.pendingCount(), 0);
    expect(await queue.failedCount(), 1);
  });

  test('a remote change from another device is pulled in', () async {
    api.seedRemoteChange(
      TestEntity.table,
      const TestEntity(
        id: 'p7',
        name: 'From the web app',
        updatedAt: now,
        deviceId: 'device-b',
      ).toJson(),
    );

    final report = await engine.sync();

    expect(report.pulled, 1);
    expect((await read('p7'))!.name, 'From the web app');
    // Anything that arrived from the server is already synced; writing it as
    // pending would push it straight back out.
    expect((await read('p7'))!.syncStatus, SyncStatus.synced);
  });

  test('a newer local edit is not overwritten by an older server row',
      () async {
    await saveLocally(id: 'p9', name: 'Newer local', updatedAt: now + 5000);

    api.seedRemoteChange(
      TestEntity.table,
      const TestEntity(
        id: 'p9',
        name: 'Older server',
        updatedAt: now,
        deviceId: 'device-b',
      ).toJson(),
    );

    await engine.sync();

    expect((await read('p9'))!.name, 'Newer local');
  });

  test('a deletion arrives as a tombstone rather than a missing row', () async {
    api.seedRemoteChange(
      TestEntity.table,
      const TestEntity(
        id: 'p4',
        name: 'Removed elsewhere',
        updatedAt: now,
        isDeleted: true,
        deviceId: 'device-b',
      ).toJson(),
    );

    await engine.sync();

    // The row is present and flagged, not absent. A hard delete would be
    // invisible to this device, which would then resurrect it on its next push.
    final row = await read('p4');
    expect(row, isNotNull);
    expect(row!.isDeleted, isTrue);
  });

  test('the pull cursor advances so the next sync only fetches new rows',
      () async {
    api.seedRemoteChange(
      TestEntity.table,
      const TestEntity(id: 'p2', name: 'First', updatedAt: now).toJson(),
    );

    await engine.sync();
    expect(cursors.cursorFor(TestEntity.table), isNotNull);

    final second = await engine.sync();
    expect(second.pulled, 0);
  });

  test('sync is a no-op when no backend is configured', () async {
    engine = buildEngine(const NoopSyncApi());
    await saveLocally();

    final report = await engine.sync();

    expect(report.error, isNotNull);
    expect(
      await queue.pendingCount(),
      1,
      reason: 'nothing was sent, so nothing may be dropped',
    );
  });
}
