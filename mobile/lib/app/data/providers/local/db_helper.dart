import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/constants/db_constants.dart';
import '../../models/customer.dart';
import '../../models/fiscal_year.dart';
import '../../models/purchase.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../models/sale_payment.dart';
import '../../models/supplier.dart';
import '../../models/supplier_payment.dart';
import 'sync_queue_dao.dart';

/// Owns the SQLite connection and the schema.
///
/// SQLite rather than a key-value store because every screen that matters here
/// is an aggregate: what is owed per supplier, takings per day, cheques due
/// this week. Those are one `GROUP BY` in SQL and a nested Dart loop over every
/// document otherwise.
class DbHelper {
  DbHelper._();

  static final DbHelper instance = DbHelper._();

  static const String _dbName = 'billrecord.db';

  /// Bump when the schema changes and add a step to [_onUpgrade].
  static const int _dbVersion = 1;

  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('DbHelper.open() must run before any DAO is used.');
    }
    return database;
  }

  bool get isOpen => _db != null;

  Future<Database> open() async {
    if (_db != null) return _db!;

    // sqflite ships a native implementation for Android/iOS only; desktop runs
    // through the FFI factory. Doing this here keeps `flutter run -d windows`
    // working for development without touching any calling code.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Off by default in SQLite; without it a sale's lines would survive
        // their parent.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Every statement needed to build the schema from nothing, in order.
  ///
  /// Public so the tests can open an in-memory database from the exact list the
  /// app ships rather than a hand-maintained copy - a copy drifts, and a schema
  /// test running against a stale copy proves nothing.
  static List<String> get schemaStatements => [
        ..._tables,
        SyncQueueDao.createTableSql,
        ..._indexes,
      ];

  /// Order matters: a child's `REFERENCES` clause needs its parent to exist.
  static final List<String> _tables = [
    FiscalYear.createTableSql,
    Supplier.createTableSql,
    Customer.createTableSql,
    Purchase.createTableSql,
    SupplierPayment.createTableSql,
    Sale.createTableSql,
    SaleItem.createTableSql,
    SalePayment.createTableSql,
  ];

  /// Carried over from the Postgres schema, plus one `sync_status` index per
  /// synced table for the pending-count query.
  ///
  /// The four unique indexes mirror the server's constraints, so a duplicate
  /// bill number is refused on the device rather than surviving locally until a
  /// sync rejects it - by which time the shopkeeper has moved on.
  static final List<String> _indexes = [
    FiscalYear.uniqueNameSql,
    Purchase.uniqueBillNoSql,
    SupplierPayment.uniqueVoucherSql,
    Sale.uniqueInvoiceSql,
    'CREATE INDEX IF NOT EXISTS idx_fiscal_year_active ON ${DbTables.fiscalYear} (is_active)',
    'CREATE INDEX IF NOT EXISTS idx_fiscal_year_sync ON ${DbTables.fiscalYear} (sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_supplier_name ON ${DbTables.supplier} (name)',
    'CREATE INDEX IF NOT EXISTS idx_supplier_sync ON ${DbTables.supplier} (sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_customer_name ON ${DbTables.customer} (name)',
    'CREATE INDEX IF NOT EXISTS idx_customer_sync ON ${DbTables.customer} (sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_purchase_supplier ON ${DbTables.purchase} (supplier_id)',
    'CREATE INDEX IF NOT EXISTS idx_purchase_date ON ${DbTables.purchase} (bill_date)',
    'CREATE INDEX IF NOT EXISTS idx_purchase_fy ON ${DbTables.purchase} (fiscal_year_id)',
    'CREATE INDEX IF NOT EXISTS idx_purchase_sync ON ${DbTables.purchase} (sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_sup_payment_supplier ON ${DbTables.supplierPayment} (supplier_id)',
    'CREATE INDEX IF NOT EXISTS idx_sup_payment_date ON ${DbTables.supplierPayment} (payment_date)',
    'CREATE INDEX IF NOT EXISTS idx_sup_payment_status ON ${DbTables.supplierPayment} (status)',
    // The cheque register reads this one: cheques ordered by the date written
    // on them, which is the order the money has to be available in.
    'CREATE INDEX IF NOT EXISTS idx_sup_payment_cheque_date ON ${DbTables.supplierPayment} (cheque_date)',
    'CREATE INDEX IF NOT EXISTS idx_sup_payment_purchase ON ${DbTables.supplierPayment} (purchase_id)',
    'CREATE INDEX IF NOT EXISTS idx_sup_payment_sync ON ${DbTables.supplierPayment} (sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_sale_date ON ${DbTables.sale} (sale_date)',
    'CREATE INDEX IF NOT EXISTS idx_sale_fy ON ${DbTables.sale} (fiscal_year_id)',
    'CREATE INDEX IF NOT EXISTS idx_sale_customer ON ${DbTables.sale} (customer_id)',
    'CREATE INDEX IF NOT EXISTS idx_sale_type ON ${DbTables.sale} (sale_type)',
    'CREATE INDEX IF NOT EXISTS idx_sale_sync ON ${DbTables.sale} (sync_status)',
    'CREATE INDEX IF NOT EXISTS idx_sale_item_sale ON ${DbTables.saleItem} (sale_id)',
    'CREATE INDEX IF NOT EXISTS idx_sale_payment_sale ON ${DbTables.salePayment} (sale_id)',
    'CREATE INDEX IF NOT EXISTS idx_queue_created ON ${DbTables.syncQueue} (created_at)',
  ];

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final sql in schemaStatements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrations are additive and idempotent, one `if` per version step:
    //   if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
    // Never drop a column - an older client may still be pushing it.
  }

  /// Wipes user data but keeps the schema - used by Settings > Reset.
  ///
  /// Children before parents: foreign keys are on, so deleting a sale while its
  /// lines still reference it would fail the whole batch.
  Future<void> clearAll() async {
    final batch = db.batch();
    for (final table in [
      DbTables.salePayment,
      DbTables.saleItem,
      DbTables.sale,
      DbTables.supplierPayment,
      DbTables.purchase,
      DbTables.customer,
      DbTables.supplier,
      DbTables.fiscalYear,
      DbTables.syncQueue,
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }

  Future<File?> databaseFile() async {
    final dir = await getDatabasesPath();
    final file = File(p.join(dir, _dbName));
    return file.existsSync() ? file : null;
  }
}
