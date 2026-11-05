import 'package:billrecord/app/core/constants/db_constants.dart';
import 'package:billrecord/app/data/models/customer_payment.dart';
import 'package:billrecord/app/data/providers/local/account_dao.dart';
import 'package:billrecord/app/data/providers/local/activity_dao.dart';
import 'package:billrecord/app/data/providers/local/customer_dao.dart';
import 'package:billrecord/app/data/providers/local/db_helper.dart';
import 'package:billrecord/app/data/providers/local/sale_dao.dart';
import 'package:billrecord/app/data/providers/local/supplier_payment_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A phone already in the shop has real records on it. Upgrading it must keep
/// them, and leave it able to run every new query.
void main() {
  late Database db;

  /// Today's schema with this release taken back out: what version 3 looked like.
  Future<void> rewindToVersion3() async {
    await db.execute('DROP TABLE ${DbTables.account}');
    await db.execute('DROP TABLE ${DbTables.customerPayment}');
    await db.execute('DROP TABLE ${DbTables.accountEntry}');
    await db.execute(
      'ALTER TABLE ${DbTables.supplierPayment} DROP COLUMN account_id',
    );
    await db.execute(
      'ALTER TABLE ${DbTables.salePayment} DROP COLUMN account_id',
    );
  }

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final sql in DbHelper.schemaStatements) {
      await db.execute(sql);
    }
    await rewindToVersion3();

    await db.insert(DbTables.sale, {
      'id': 's1',
      'fiscal_year_id': 'fy',
      'sale_date': 1000,
      'sale_type': 'SUMMARY',
      'total_amount': 5000,
      'subtotal': 5000,
      'discount': 0,
      'created_at': 1,
      'updated_at': 1,
    });
    await db.insert(DbTables.salePayment, {
      'id': 'l1',
      'sale_id': 's1',
      'payment_mode': 'CASH',
      'amount': 5000,
      'status': 'CLEARED',
      'created_at': 1,
    });
  });

  tearDown(() async => db.close());

  test('keeps the records and runs every new query', () async {
    await DbHelper.instance.upgrade(db, 3, 4);

    final sale = await SaleDao(db).byId('s1');
    expect(sale!.payments.single.accountId, isNull);

    // Every query that joins the new tables.
    await SupplierPaymentDao(db).all();
    await CustomerDao(db).receivable();
    await ActivityDao(db).feed();
    await ActivityDao(db).cheques();
    await AccountDao(db).unassignedTotal();

    final rows = await db.query(DbTables.customerPayment);
    expect(rows, isEmpty);
    expect(CustomerPayment.createTableSql, contains(DbTables.customerPayment));
  });

  test('old cash counts towards the cash box without any editing', () async {
    await DbHelper.instance.upgrade(db, 3, 4);

    final movements = await AccountDao(
      db,
    ).movements('00000000-0000-4000-8000-000000000001');
    expect(movements.single.amount.paisa, 5000);
  });

  test('ends up with the same columns as a fresh install', () async {
    await DbHelper.instance.upgrade(db, 3, 4);

    final fresh = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final sql in DbHelper.schemaStatements) {
      await fresh.execute(sql);
    }

    Future<Set<String>> columns(Database d, String table) async =>
        (await d.rawQuery('PRAGMA table_info($table)'))
            .map((c) => c['name'] as String)
            .toSet();

    for (final table in [
      DbTables.account,
      DbTables.customerPayment,
      DbTables.accountEntry,
      DbTables.salePayment,
      DbTables.supplierPayment,
    ]) {
      expect(await columns(db, table), await columns(fresh, table), reason: table);
    }
    await fresh.close();
  });
}
