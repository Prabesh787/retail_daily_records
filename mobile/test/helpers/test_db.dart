import 'package:billrecord/app/core/constants/db_constants.dart';
import 'package:billrecord/app/data/providers/local/db_helper.dart';
import 'package:billrecord/app/data/sync/entity_syncer.dart';
import 'package:billrecord/app/data/sync/sync_engine.dart';
import 'package:billrecord/app/data/enums/sync_status.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// An in-memory database built from [DbHelper.schemaStatements] — the exact
/// list the app runs on a fresh install, not a copy of it. A copy drifts, and a
/// schema test running against a stale copy proves nothing.
///
/// [TestEntity] is added alongside it. The sync engine's own tests use that
/// rather than a real entity on purpose: the engine's behaviour — push, pull,
/// conflict, retry, cursors — has nothing to do with what a supplier is, and
/// tying those tests to a domain model means they break every time the domain
/// changes and stop being about the engine at all.
Future<Database> openTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  await db.execute('PRAGMA foreign_keys = ON');
  for (final sql in [...DbHelper.schemaStatements, TestEntity.createTableSql]) {
    await db.execute(sql);
  }
  return db;
}

/// The smallest thing that can be synced: an id, a name, and the sync columns
/// every entity carries.
class TestEntity {
  const TestEntity({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
    this.deviceId,
  });

  static const String table = 'test_rows';

  final String id;
  final String name;
  final int updatedAt;
  final bool isDeleted;
  final SyncStatus syncStatus;
  final String? deviceId;

  Map<String, dynamic> toMap() => {
        SyncColumns.id: id,
        'name': name,
        SyncColumns.createdAt: updatedAt,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.isDeleted: isDeleted ? 1 : 0,
        SyncColumns.syncStatus: syncStatus.code,
        SyncColumns.deviceId: deviceId,
      };

  /// What goes over the wire. Sync metadata is snake_case because that is what
  /// `SyncEngine` reads off a pulled row.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': updatedAt,
        'updated_at': updatedAt,
        'is_deleted': isDeleted,
        'device_id': deviceId,
      };

  static TestEntity fromMap(Map<String, dynamic> map) => TestEntity(
        id: map[SyncColumns.id] as String,
        name: (map['name'] as String?) ?? '',
        updatedAt: (map[SyncColumns.updatedAt] as int?) ?? 0,
        isDeleted: (map[SyncColumns.isDeleted] as int?) == 1,
        syncStatus: SyncStatus.fromCode(map[SyncColumns.syncStatus] as int?),
        deviceId: map[SyncColumns.deviceId] as String?,
      );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS $table (
      id   TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      ${SyncColumns.definition}
    )
  ''';
}

/// Lands [TestEntity] rows locally, the way a real syncer lands its entity.
class TestEntitySyncer extends EntitySyncer {
  const TestEntitySyncer(super.db);

  @override
  String get entity => TestEntity.table;

  @override
  Future<void> applyRemote(Map<String, dynamic> row) async {
    await db.insert(
      TestEntity.table,
      TestEntity(
        id: row['id'] as String,
        name: (row['name'] as String?) ?? '',
        updatedAt: (row['updated_at'] as num?)?.toInt() ?? 0,
        isDeleted: row['is_deleted'] == true || row['is_deleted'] == 1,
        // Anything that arrived from the server is by definition already
        // synced; writing it as pending would push it straight back out.
        syncStatus: SyncStatus.synced,
        deviceId: row['device_id'] as String?,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// In-memory stand-in for StorageService's cursor storage.
class FakeCursorStore implements SyncCursorStore {
  final Map<String, String?> cursors = {};

  @override
  int? lastSyncedAt;

  @override
  String? cursorFor(String entity) => cursors[entity];

  @override
  void setCursor(String entity, String? cursor) => cursors[entity] = cursor;
}
