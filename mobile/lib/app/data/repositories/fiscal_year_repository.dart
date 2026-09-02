import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../core/errors/app_exception.dart';
import '../enums/sync_status.dart';
import '../models/fiscal_year.dart';
import 'base_repository.dart';

class FiscalYearRepository extends BaseRepository {
  Future<List<FiscalYear>> list() => dbService.fiscalYears.all();

  Future<FiscalYear?> byId(String id) => dbService.fiscalYears.byId(id);

  Future<FiscalYear?> active() => dbService.fiscalYears.active();

  /// The year a document dated [dateMs] belongs to.
  ///
  /// Falls back to the active year when none covers the date, so a form is
  /// never blocked — but the caller should say which it used, because filing a
  /// bill under a year that does not contain its own date is how a row ends up
  /// somewhere nobody thinks to look.
  Future<FiscalYear?> forDate(int dateMs) async =>
      await dbService.fiscalYears.covering(dateMs) ??
      await dbService.fiscalYears.active();

  /// Creates or updates a year. Pass an empty [FiscalYear.id] to create.
  ///
  /// Marking one active is part of the same write, not a second call: the flag
  /// is cleared on every other year inside the same transaction, so there is
  /// never a moment with two active years or none.
  Future<FiscalYear> save(FiscalYear year) async {
    final name = year.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('A fiscal year needs a name.');
    }
    if (year.endDate <= year.startDate) {
      throw const ValidationException('The year has to end after it starts.');
    }

    final isNew = year.id.isEmpty;
    if (await dbService.fiscalYears
        .nameExists(name, exceptId: isNew ? null : year.id)) {
      throw ValidationException('$name already exists.');
    }

    final timestamp = nowMs;
    final stamped = isNew
        ? FiscalYear(
            id: newId(),
            createdAt: timestamp,
            updatedAt: timestamp,
            name: name,
            startDate: year.startDate,
            endDate: year.endDate,
            startDateBs: year.startDateBs,
            endDateBs: year.endDateBs,
            isActive: year.isActive,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          )
        : year.copyWith(
            name: name,
            updatedAt: timestamp,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          );

    await write((txn) async {
      await dbService.fiscalYears.upsert(txn, stamped);
      await enqueue(
        txn,
        entity: DbTables.fiscalYear,
        entityId: stamped.id,
        payload: stamped.toJson(),
        updatedAt: timestamp,
      );
      if (stamped.isActive) {
        await _deactivateOthers(txn, stamped.id, timestamp);
      }
    });

    return stamped;
  }

  /// Makes [id] the year new records are filed under.
  Future<FiscalYear?> activate(String id) async {
    final year = await byId(id);
    if (year == null) return null;

    final timestamp = nowMs;
    final activated = year.copyWith(
      isActive: true,
      updatedAt: timestamp,
      syncStatus: SyncStatus.pending,
      deviceId: deviceId,
    );

    await write((txn) async {
      await dbService.fiscalYears.upsert(txn, activated);
      await enqueue(
        txn,
        entity: DbTables.fiscalYear,
        entityId: activated.id,
        payload: activated.toJson(),
        updatedAt: timestamp,
      );
      await _deactivateOthers(txn, activated.id, timestamp);
    });

    return activated;
  }

  /// Clears the flag on the other years **and queues each one for push**.
  ///
  /// Queueing matters: a flag flipped only locally leaves two devices
  /// disagreeing about which year is current, and the disagreement is invisible
  /// until something is filed under the wrong one.
  Future<void> _deactivateOthers(
    DatabaseExecutor txn,
    String keepId,
    int timestamp,
  ) async {
    final others = await dbService.fiscalYears.othersActive(txn, keepId);

    for (final other in others) {
      final cleared = other.copyWith(
        isActive: false,
        updatedAt: timestamp,
        syncStatus: SyncStatus.pending,
        deviceId: deviceId,
      );
      await dbService.fiscalYears.upsert(txn, cleared);
      await enqueue(
        txn,
        entity: DbTables.fiscalYear,
        entityId: cleared.id,
        payload: cleared.toJson(),
        updatedAt: timestamp,
      );
    }
  }

  /// Soft delete. A year with anything filed under it refuses — the same rule
  /// the server applies, and for the same reason: the documents would be
  /// orphaned.
  Future<void> delete(String id) async {
    final existing = await byId(id);
    if (existing == null) return;

    if (await dbService.fiscalYears.hasTransactions(id)) {
      throw ValidationException(
        '${existing.name} has records filed under it and cannot be removed.',
      );
    }

    final timestamp = nowMs;
    await write((txn) async {
      await dbService.fiscalYears.softDelete(txn, id, timestamp);
      await enqueue(
        txn,
        entity: DbTables.fiscalYear,
        entityId: id,
        operation: SyncOperationType.delete,
        payload:
            existing.copyWith(isDeleted: true, updatedAt: timestamp).toJson(),
        updatedAt: timestamp,
      );
    });
  }
}
