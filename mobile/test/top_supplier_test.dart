import 'dart:io';

import 'package:billrecord/app/core/constants/db_constants.dart';
import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/data/dto/retail_dto.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/providers/local/supplier_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// A supplier marked as top is pinned above the rest, whatever they are owed,
/// and the mark has to survive the trip to the server and back.
void main() {
  late Database db;
  late SupplierDao suppliers;

  const int now = 1700000000000;

  Supplier supplier(String id, String name, {bool isTop = false}) => Supplier(
    id: id,
    createdAt: now,
    updatedAt: now,
    name: name,
    isTop: isTop,
  );

  Future<void> bill(String supplierId, String amount) => db.insert(
    DbTables.purchase,
    Purchase(
      id: 'bill-$supplierId',
      createdAt: now,
      updatedAt: now,
      fiscalYearId: 'fy',
      supplierId: supplierId,
      billNo: supplierId,
      billDate: now,
      amount: Money.fromWire(amount),
    ).toMap(),
  );

  setUp(() async {
    db = await openTestDb();
    suppliers = SupplierDao(db);
  });

  tearDown(() => db.close());

  test('top suppliers come first, even when owed less', () async {
    await suppliers.upsert(db, supplier('a', 'Big Debt'));
    await suppliers.upsert(db, supplier('b', 'Top Small', isTop: true));
    await suppliers.upsert(db, supplier('c', 'Top Large', isTop: true));
    await suppliers.upsert(db, supplier('d', 'Settled'));
    await bill('a', '90000.00');
    await bill('b', '1000.00');
    await bill('c', '5000.00');

    final names = (await suppliers.all()).map((s) => s.name).toList();

    // Within each group the usual order still holds: largest debt first.
    expect(names, ['Top Large', 'Top Small', 'Big Debt', 'Settled']);
  });

  test('the flag round trips through SQLite and the wire', () async {
    await suppliers.upsert(db, supplier('a', 'Pinned', isTop: true));

    final read = (await suppliers.byId('a'))!;
    expect(read.isTop, isTrue);

    final json = read.toJson();
    expect(json['isTop'], isTrue);
    expect(
      SupplierDto.fromWire({
        ...json,
        'created_at': now,
        'updated_at': now,
      }).isTop,
      isTrue,
    );
    // An older server that does not send the field leaves it unpinned.
    expect(SupplierDto.fromWire({'id': 'x', 'name': 'Old'}).isTop, isFalse);
  });

  test('upgrading an existing database adds the column, unpinned', () async {
    final dir = await Directory.systemTemp.createTemp('supplier_upgrade');
    final old = await databaseFactoryFfi.openDatabase(
      p.join(dir.path, 'v2.db'),
    );
    await old.execute('''
      CREATE TABLE ${DbTables.supplier} (
        id TEXT PRIMARY KEY, name TEXT NOT NULL,
        opening_balance INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        ${SyncColumns.definition}
      )
    ''');
    await old.insert(DbTables.supplier, {
      'id': 'a',
      'name': 'Existing',
      SyncColumns.createdAt: now,
      SyncColumns.updatedAt: now,
    });

    await old.execute(Supplier.addIsTopSql);

    final row = (await old.query(DbTables.supplier)).single;
    expect(Supplier.fromMap(row).isTop, isFalse);
    await old.close();
    dir.deleteSync(recursive: true);
  });
}
