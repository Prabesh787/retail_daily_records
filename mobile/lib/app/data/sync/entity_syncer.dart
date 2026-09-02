import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../dto/retail_dto.dart';
import '../enums/sync_status.dart';
import '../providers/local/customer_dao.dart';
import '../providers/local/fiscal_year_dao.dart';
import '../providers/local/purchase_dao.dart';
import '../providers/local/sale_dao.dart';
import '../providers/local/supplier_dao.dart';
import '../providers/local/supplier_payment_dao.dart';

/// Teaches the engine how to land one entity's rows locally.
///
/// The engine owns the *when* (push, then pull, per table, in dependency
/// order); a syncer owns the *what* for its table. Adding a synced entity is
/// then one subclass plus one line in [buildSyncers] - no change to the engine
/// itself.
abstract class EntitySyncer {
  const EntitySyncer(this.db);

  final Database db;

  /// Wire name for this entity; also the table name and the cursor key.
  String get entity;

  /// Applies a server row. Implementations write with `sync_status = synced` so
  /// the row is not immediately queued straight back to the server.
  Future<void> applyRemote(Map<String, dynamic> row);

  /// Local `updated_at`, or null when this device has never seen the row.
  Future<int?> localUpdatedAt(String id) async {
    final rows = await db.query(
      entity,
      columns: [SyncColumns.updatedAt],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[SyncColumns.updatedAt] as int?;
  }

  Future<bool> localIsPending(String id) async {
    final rows = await db.query(
      entity,
      columns: [SyncColumns.syncStatus],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first[SyncColumns.syncStatus] as int?) ==
        SyncStatus.pending.code;
  }

  /// Marks a pushed row as synced - but only if it has not been edited since
  /// the payload was queued. The `updated_at <= ?` guard is what stops an edit
  /// made during an in-flight push from being silently marked as delivered.
  Future<void> markSynced(String id, int pushedUpdatedAt) async {
    await db.update(
      entity,
      {SyncColumns.syncStatus: SyncStatus.synced.code},
      where: 'id = ? AND ${SyncColumns.updatedAt} <= ?',
      whereArgs: [id, pushedUpdatedAt],
    );
  }
}

/// The registry the app runs on, in dependency order: parents first, so a
/// purchase can never land before the supplier it belongs to.
///
/// Sale items and sale payments are absent on purpose - they are not entities
/// on the wire, they travel inside a sale's payload.
List<EntitySyncer> buildSyncers(Database db) => [
      FiscalYearSyncer(db),
      SupplierSyncer(db),
      CustomerSyncer(db),
      PurchaseSyncer(db),
      SupplierPaymentSyncer(db),
      SaleSyncer(db),
    ];

class FiscalYearSyncer extends EntitySyncer {
  FiscalYearSyncer(super.db) : _dao = FiscalYearDao(db);

  final FiscalYearDao _dao;

  @override
  String get entity => DbTables.fiscalYear;

  @override
  Future<void> applyRemote(Map<String, dynamic> row) =>
      _dao.upsert(db, FiscalYearDto.fromWire(row));
}

class SupplierSyncer extends EntitySyncer {
  SupplierSyncer(super.db) : _dao = SupplierDao(db);

  final SupplierDao _dao;

  @override
  String get entity => DbTables.supplier;

  @override
  Future<void> applyRemote(Map<String, dynamic> row) =>
      _dao.upsert(db, SupplierDto.fromWire(row));
}

class CustomerSyncer extends EntitySyncer {
  CustomerSyncer(super.db) : _dao = CustomerDao(db);

  final CustomerDao _dao;

  @override
  String get entity => DbTables.customer;

  @override
  Future<void> applyRemote(Map<String, dynamic> row) =>
      _dao.upsert(db, CustomerDto.fromWire(row));
}

class PurchaseSyncer extends EntitySyncer {
  PurchaseSyncer(super.db) : _dao = PurchaseDao(db);

  final PurchaseDao _dao;

  @override
  String get entity => DbTables.purchase;

  @override
  Future<void> applyRemote(Map<String, dynamic> row) =>
      _dao.upsert(db, PurchaseDto.fromWire(row));
}

class SupplierPaymentSyncer extends EntitySyncer {
  SupplierPaymentSyncer(super.db) : _dao = SupplierPaymentDao(db);

  final SupplierPaymentDao _dao;

  @override
  String get entity => DbTables.supplierPayment;

  @override
  Future<void> applyRemote(Map<String, dynamic> row) =>
      _dao.upsert(db, SupplierPaymentDto.fromWire(row));
}

class SaleSyncer extends EntitySyncer {
  SaleSyncer(super.db) : _dao = SaleDao(db);

  final SaleDao _dao;

  @override
  String get entity => DbTables.sale;

  /// Header, lines and settlement land in one transaction - a sale whose items
  /// were half applied would show a total that does not match its own rows.
  ///
  /// The children are replaced rather than merged: they carry no identity the
  /// user cares about, and the server's copy is authoritative for all of them.
  @override
  Future<void> applyRemote(Map<String, dynamic> row) async {
    final sale = SaleDto.fromWire(row);
    await db.transaction((txn) async {
      await _dao.upsert(txn, sale);
      await _dao.replaceItems(txn, sale.id, sale.items);
      await _dao.replacePayments(txn, sale.id, sale.payments);
    });
  }
}
