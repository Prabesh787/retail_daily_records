import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/sync_status.dart';
import '../models/purchase.dart';
import 'base_repository.dart';

class PurchaseRepository extends BaseRepository {
  Future<List<Purchase>> list({
    String? supplierId,
    String? fiscalYearId,
    int? fromMs,
    int? toMs,
    String? search,
    bool onlyUnpaid = false,
    int? limit,
  }) =>
      dbService.purchases.all(
        supplierId: supplierId,
        fiscalYearId: fiscalYearId,
        fromMs: fromMs,
        toMs: toMs,
        search: search,
        onlyUnpaid: onlyUnpaid,
        limit: limit,
      );

  Future<Purchase?> byId(String id) => dbService.purchases.byId(id);

  Future<({Money total, int count})> totalBetween(int fromMs, int toMs) =>
      dbService.purchases.totalBetween(fromMs, toMs);

  /// Records a wholesale bill.
  ///
  /// The BS date is filled in from the AD date when the caller did not supply
  /// one, so a bill saved from a screen that only offered an AD picker still
  /// prints correctly. When the caller *did* supply one it wins — it is what
  /// was written on the paper.
  Future<Purchase> save(Purchase purchase) async {
    final billNo = purchase.billNo.trim();
    if (billNo.isEmpty) {
      throw const ValidationException('A bill needs its number.');
    }
    if (purchase.supplierId.isEmpty) {
      throw const ValidationException('A bill needs a supplier.');
    }
    if (purchase.fiscalYearId.isEmpty) {
      throw const ValidationException(
        'There is no fiscal year to file this bill under.',
      );
    }
    if (!purchase.amount.isPositive) {
      throw const ValidationException('A bill amount has to be more than zero.');
    }

    final isNew = purchase.id.isEmpty;

    // Asked before inserting so the form can say it in words. The unique index
    // would refuse it anyway — this is the difference between a message and a
    // database exception surfacing in the UI.
    if (await dbService.purchases.billNoExists(
      supplierId: purchase.supplierId,
      fiscalYearId: purchase.fiscalYearId,
      billNo: billNo,
      exceptId: isNew ? null : purchase.id,
    )) {
      throw ValidationException(
        'Bill $billNo is already recorded for this supplier this year.',
      );
    }

    final timestamp = nowMs;
    final billDateBs =
        purchase.billDateBs ?? NepaliDate.msToBs(purchase.billDate);

    final stamped = isNew
        ? Purchase(
            id: newId(),
            createdAt: timestamp,
            updatedAt: timestamp,
            fiscalYearId: purchase.fiscalYearId,
            supplierId: purchase.supplierId,
            billNo: billNo,
            billDate: purchase.billDate,
            billDateBs: billDateBs,
            description: purchase.description,
            amount: purchase.amount,
            remarks: purchase.remarks,
            createdById: purchase.createdById,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          )
        : purchase.copyWith(
            billNo: billNo,
            billDateBs: billDateBs,
            updatedAt: timestamp,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          );

    await write((txn) async {
      await dbService.purchases.upsert(txn, stamped);
      await enqueue(
        txn,
        entity: DbTables.purchase,
        entityId: stamped.id,
        payload: stamped.toJson(),
        updatedAt: timestamp,
      );
    });

    return stamped;
  }

  /// Soft delete. Refuses while payments point at the bill — settling a bill
  /// that no longer exists is not a state the ledger can explain.
  Future<void> delete(String id) async {
    final existing = await byId(id);
    if (existing == null) return;

    if (await dbService.purchases.hasPayments(id)) {
      throw const ValidationException(
        'Payments are recorded against this bill. Remove them first.',
      );
    }

    final timestamp = nowMs;
    await write((txn) async {
      await dbService.purchases.softDelete(txn, id, timestamp);
      await enqueue(
        txn,
        entity: DbTables.purchase,
        entityId: id,
        operation: SyncOperationType.delete,
        payload:
            existing.copyWith(isDeleted: true, updatedAt: timestamp).toJson(),
        updatedAt: timestamp,
      );
    });
  }
}
