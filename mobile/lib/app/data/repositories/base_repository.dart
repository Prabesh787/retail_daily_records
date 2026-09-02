import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/sync_service.dart';
import '../enums/sync_status.dart';
import '../providers/local/sync_queue_dao.dart';

/// Shared plumbing for the repositories.
///
/// Repositories are the only layer that writes. Controllers call them, they
/// call the DAOs, and — critically — they are where a data write and its
/// outbox entry are wrapped in a single transaction. That pairing is the whole
/// offline guarantee: if the row exists, the change to push exists too.
abstract class BaseRepository {
  static const Uuid _uuid = Uuid();

  DatabaseService get dbService => Get.find<DatabaseService>();
  StorageService get storage => Get.find<StorageService>();

  /// Client-generated primary key.
  ///
  /// Not a server auto-increment: a bill created with no signal has to be
  /// valid immediately, and its line items have to be able to reference it
  /// before it has ever reached a server. Two devices creating rows offline
  /// then cannot collide.
  String newId() => _uuid.v4();

  String get deviceId => storage.deviceId;

  int get nowMs => DateTime.now().millisecondsSinceEpoch;

  /// Every write goes through here: the DAO call and the queue insert share
  /// one [Transaction], so a crash between them is impossible.
  Future<T> write<T>(Future<T> Function(Transaction txn) action) async {
    final result = await dbService.transaction(action);
    _notifySync();
    return result;
  }

  Future<void> enqueue(
    DatabaseExecutor txn, {
    required String entity,
    required String entityId,
    required Map<String, dynamic> payload,
    required int updatedAt,
    SyncOperationType operation = SyncOperationType.upsert,
  }) =>
      SyncQueueDao.enqueueIn(
        txn,
        entity: entity,
        entityId: entityId,
        operation: operation,
        updatedAt: updatedAt,
        payload: payload,
      );

  /// Keeps the pending-count chip honest after a local write. Fire-and-forget:
  /// the user's save has already completed and must not wait on this.
  void _notifySync() {
    if (Get.isRegistered<SyncService>()) {
      Get.find<SyncService>().refreshCounts();
    }
  }
}
