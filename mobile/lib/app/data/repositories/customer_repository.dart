import '../../core/constants/db_constants.dart';
import '../../core/errors/app_exception.dart';
import '../enums/sync_status.dart';
import '../models/customer.dart';
import 'base_repository.dart';

class CustomerRepository extends BaseRepository {
  Future<List<Customer>> list({String? search}) =>
      dbService.customers.all(search: search);

  Future<Customer?> byId(String id) => dbService.customers.byId(id);

  Future<int> count() => dbService.customers.count();

  Future<Customer> save(Customer customer) async {
    final name = customer.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('A customer needs a name.');
    }

    final timestamp = nowMs;
    final isNew = customer.id.isEmpty;

    final stamped = isNew
        ? Customer(
            id: newId(),
            createdAt: timestamp,
            updatedAt: timestamp,
            name: name,
            phone: customer.phone,
            address: customer.address,
            pan: customer.pan,
            remarks: customer.remarks,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          )
        : customer.copyWith(
            name: name,
            updatedAt: timestamp,
            syncStatus: SyncStatus.pending,
            deviceId: deviceId,
          );

    await write((txn) async {
      await dbService.customers.upsert(txn, stamped);
      await enqueue(
        txn,
        entity: DbTables.customer,
        entityId: stamped.id,
        payload: stamped.toJson(),
        updatedAt: timestamp,
      );
    });

    return stamped;
  }

  /// Soft delete. A customer with invoices refuses — those sales would lose the
  /// name they were made out to.
  Future<void> delete(String id) async {
    final existing = await byId(id);
    if (existing == null) return;

    if (await dbService.customers.hasSales(id)) {
      throw ValidationException(
        '${existing.name} has invoices recorded and cannot be removed.',
      );
    }

    final timestamp = nowMs;
    await write((txn) async {
      await dbService.customers.softDelete(txn, id, timestamp);
      await enqueue(
        txn,
        entity: DbTables.customer,
        entityId: id,
        operation: SyncOperationType.delete,
        payload:
            existing.copyWith(isDeleted: true, updatedAt: timestamp).toJson(),
        updatedAt: timestamp,
      );
    });
  }
}
