import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import '../../core/errors/app_exception.dart';
import '../enums/sync_status.dart';
import '../models/supplier.dart';
import 'base_repository.dart';

class SupplierRepository extends BaseRepository {
  /// Ordered by what is owed, largest first — the list is a payables worklist,
  /// not an address book.
  Future<List<Supplier>> list({
    String? search,
    bool onlyWithBalance = false,
    bool includeInactive = true,
  }) =>
      dbService.suppliers.all(
        search: search,
        onlyWithBalance: onlyWithBalance,
        includeInactive: includeInactive,
      );

  Future<Supplier?> byId(String id) => dbService.suppliers.byId(id);

  Future<List<Supplier>> topOutstanding({int limit = 4}) =>
      dbService.suppliers.topOutstanding(limit: limit);

  Future<({Money total, int supplierCount})> payable() =>
      dbService.suppliers.payable();

  Future<int> count() => dbService.suppliers.count();

  Future<bool> hasTransactions(String id) =>
      dbService.suppliers.hasTransactions(id);

  Future<Supplier> save(Supplier supplier) async {
    final name = supplier.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('A supplier needs a name.');
    }

    final isNew = supplier.id.isEmpty;

    // Two suppliers with the same name is not illegal, but it is almost always
    // a duplicate being entered twice — and a duplicate splits one balance in
    // half, which is the failure this whole app exists to prevent.
    if (await dbService.suppliers
        .nameExists(name, exceptId: isNew ? null : supplier.id)) {
      throw ValidationException('There is already a supplier called $name.');
    }

    final timestamp = nowMs;
    final stamped = isNew
        ? Supplier(
            id: newId(),
            createdAt: timestamp,
            updatedAt: timestamp,
            name: name,
            contactPerson: supplier.contactPerson,
            phone: supplier.phone,
            email: supplier.email,
            address: supplier.address,
            pan: supplier.pan,
            openingBalance: supplier.openingBalance,
            isActive: supplier.isActive,
            remarks: supplier.remarks,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          )
        : supplier.copyWith(
            name: name,
            updatedAt: timestamp,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          );

    await write((txn) async {
      await dbService.suppliers.upsert(txn, stamped);
      await enqueue(
        txn,
        entity: DbTables.supplier,
        entityId: stamped.id,
        payload: stamped.toJson(),
        updatedAt: timestamp,
      );
    });

    return stamped;
  }

  /// Soft delete only — a hard delete would be invisible to the other clients,
  /// which would resurrect the supplier on their next push.
  ///
  /// A supplier with documents against them refuses outright: their bills and
  /// payments would be orphaned and the derived balance would silently stop
  /// counting them. Deactivate instead.
  Future<void> delete(String id) async {
    final existing = await byId(id);
    if (existing == null) return;

    if (await dbService.suppliers.hasTransactions(id)) {
      throw ValidationException(
        '${existing.name} has bills or payments recorded. Mark them inactive '
        'instead of deleting them.',
      );
    }

    final timestamp = nowMs;
    await write((txn) async {
      await dbService.suppliers.softDelete(txn, id, timestamp);
      await enqueue(
        txn,
        entity: DbTables.supplier,
        entityId: id,
        operation: SyncOperationType.delete,
        payload:
            existing.copyWith(isDeleted: true, updatedAt: timestamp).toJson(),
        updatedAt: timestamp,
      );
    });
  }

  /// The way to retire a supplier who has history.
  Future<Supplier?> setActive(String id, bool isActive) async {
    final existing = await byId(id);
    if (existing == null) return null;
    return save(existing.copyWith(isActive: isActive));
  }
}
