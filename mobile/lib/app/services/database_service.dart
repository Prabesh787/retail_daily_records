import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

import '../data/providers/local/customer_dao.dart';
import '../data/providers/local/db_helper.dart';
import '../data/providers/local/fiscal_year_dao.dart';
import '../data/providers/local/purchase_dao.dart';
import '../data/providers/local/sale_dao.dart';
import '../data/providers/local/supplier_dao.dart';
import '../data/providers/local/supplier_payment_dao.dart';
import '../data/providers/local/sync_queue_dao.dart';

/// Opens the database once at startup and hands out the DAOs.
///
/// Put in via `Get.putAsync` before `runApp`, so no screen can ever render
/// against a connection that is not open yet.
class DatabaseService extends GetxService {
  static DatabaseService get to => Get.find();

  late final Database db;

  late final FiscalYearDao fiscalYears;
  late final SupplierDao suppliers;
  late final CustomerDao customers;
  late final PurchaseDao purchases;
  late final SupplierPaymentDao supplierPayments;
  late final SaleDao sales;

  late final SyncQueueDao syncQueue;

  Future<DatabaseService> init() async {
    db = await DbHelper.instance.open();

    fiscalYears = FiscalYearDao(db);
    suppliers = SupplierDao(db);
    customers = CustomerDao(db);
    purchases = PurchaseDao(db);
    supplierPayments = SupplierPaymentDao(db);
    sales = SaleDao(db);

    syncQueue = SyncQueueDao(db);
    return this;
  }

  /// Runs [action] in a single transaction.
  ///
  /// Repositories use this to write a row and its outbox entry together - the
  /// guarantee that no saved record is ever left unqueued.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      db.transaction<T>(action);

  @override
  void onClose() {
    DbHelper.instance.close();
    super.onClose();
  }
}
