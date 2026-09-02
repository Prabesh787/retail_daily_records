import 'package:billrecord/app/core/constants/db_constants.dart';
import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/utils/nepali_date.dart';
import 'package:billrecord/app/data/dto/retail_dto.dart';
import 'package:billrecord/app/data/enums/payment_status.dart';
import 'package:billrecord/app/data/enums/sale_payment_mode.dart';
import 'package:billrecord/app/data/enums/sale_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/enums/sync_status.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/sale.dart';
import 'package:billrecord/app/data/models/sale_item.dart';
import 'package:billrecord/app/data/models/sale_payment.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/providers/local/purchase_dao.dart';
import 'package:billrecord/app/data/providers/local/sale_dao.dart';
import 'package:billrecord/app/data/providers/local/supplier_dao.dart';
import 'package:billrecord/app/data/providers/local/sync_queue_dao.dart';
import 'package:billrecord/app/data/providers/remote/fake_sync_api.dart';
import 'package:billrecord/app/data/sync/conflict_resolver.dart';
import 'package:billrecord/app/data/sync/entity_syncer.dart';
import 'package:billrecord/app/data/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// The retail entities going out and coming back, against [FakeSyncApi].
///
/// The engine itself is covered by `sync_engine_test.dart`; what is tested here
/// is that the six entities survive the round trip — money as exact paisa,
/// dates as the same calendar day, and a sale with its lines and settlement
/// intact. None of it needs the real backend, which is the entire reason the
/// fake exists.
void main() {
  late Database db;
  late SyncQueueDao queue;
  late FakeSyncApi api;
  late FakeCursorStore cursors;
  late SyncEngine engine;

  const deviceId = 'device-a';
  const now = 1700000000000;
  final billDate = NepaliDate.toMs(DateTime.utc(2026, 8, 17));

  setUp(() async {
    db = await openTestDb();
    queue = SyncQueueDao(db);
    api = FakeSyncApi(latency: Duration.zero);
    cursors = FakeCursorStore();
    engine = SyncEngine(
      api: api,
      queue: queue,
      syncers: buildSyncers(db),
      cursors: cursors,
      resolver: const ConflictResolver(deviceId: deviceId),
    );
  });

  tearDown(() => db.close());

  /// Mirrors what BaseRepository does: the row and its outbox entry commit in
  /// one transaction.
  Future<void> saveLocally({
    required String entity,
    required String id,
    required Map<String, dynamic> row,
    required Map<String, dynamic> payload,
    int updatedAt = now,
  }) async {
    await db.transaction((txn) async {
      await txn.insert(entity, row,
          conflictAlgorithm: ConflictAlgorithm.replace);
      await SyncQueueDao.enqueueIn(
        txn,
        entity: entity,
        entityId: id,
        operation: SyncOperationType.upsert,
        updatedAt: updatedAt,
        payload: payload,
      );
    });
  }

  Supplier supplier({String id = 's1', String opening = '5000.00'}) => Supplier(
        id: id,
        createdAt: now,
        updatedAt: now,
        name: 'ABC Textile',
        pan: '301234567',
        openingBalance: Money.fromWire(opening),
        deviceId: deviceId,
      );

  Purchase purchase({String id = 'pur1'}) => Purchase(
        id: id,
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy1',
        supplierId: 's1',
        billNo: '4521',
        billDate: billDate,
        billDateBs: '2083-05-01',
        amount: Money.fromWire('100000.00'),
        deviceId: deviceId,
      );

  group('pushing what was recorded on this device', () {
    test('a supplier reaches the server exactly as it was saved', () async {
      final record = supplier();
      await saveLocally(
        entity: DbTables.supplier,
        id: record.id,
        row: record.toMap(),
        payload: record.toJson(),
      );

      final report = await engine.sync();

      expect(report.pushed, 1);
      expect(report.error, isNull);
      expect(await queue.pendingCount(), 0);

      final sent = api.storedFor(DbTables.supplier).single;
      expect(sent['name'], 'ABC Textile');
      // Money leaves as a fixed-precision string, never a float.
      expect(sent['openingBalance'], '5000.00');
      expect(sent['device_id'], deviceId);
    });

    test('the row is marked synced, so it is not pushed twice', () async {
      final record = supplier();
      await saveLocally(
        entity: DbTables.supplier,
        id: record.id,
        row: record.toMap(),
        payload: record.toJson(),
      );

      await engine.sync();
      expect((await SupplierDao(db).byId('s1'))!.syncStatus, SyncStatus.synced);

      expect((await engine.sync()).pushed, 0);
    });

    test('a sale carries its lines and settlement in one operation', () async {
      final sale = Sale(
        id: 'sale1',
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy1',
        invoiceNo: 'A-0012',
        saleDate: billDate,
        saleDateBs: '2083-05-01',
        saleType: SaleType.detailed,
        totalAmount: Money.zero,
        deviceId: deviceId,
        items: [
          SaleItem(
            id: 'li1',
            saleId: 'sale1',
            description: 'Printed Cotton - Blue',
            quantity: Quantity.fromWire('5'),
            unit: 'METER',
            unitPrice: Money.fromWire('800.00'),
          ),
        ],
        payments: [
          SalePayment(
            id: 'sp1',
            saleId: 'sale1',
            paymentMode: SalePaymentMode.cash,
            amount: Money.fromWire('4000.00'),
          ),
        ],
      ).recalculated;

      await saveLocally(
        entity: DbTables.sale,
        id: sale.id,
        row: sale.toMap(),
        payload: sale.toJson(),
      );

      await engine.sync();

      final sent = api.storedFor(DbTables.sale).single;
      expect((sent['items'] as List).length, 1);
      expect((sent['payments'] as List).length, 1);
      expect(sent['totalAmount'], '4000.00');
      // One operation, not three: the document is atomic on the wire.
      expect(api.storedFor(DbTables.saleItem), isEmpty);
    });
  });

  group('pulling what another device recorded', () {
    test('a purchase lands with its money and dates intact', () async {
      api.seedRemoteChange(DbTables.supplier, SupplierDto.toWire(supplier()));
      api.seedRemoteChange(DbTables.purchase, PurchaseDto.toWire(purchase()));

      expect((await engine.sync()).pulled, 2);

      final stored = (await PurchaseDao(db).byId('pur1'))!;
      expect(stored.amount, Money.fromWire('100000.00'));
      expect(stored.billNo, '4521');
      expect(stored.billDateBs, '2083-05-01');
      // The same calendar day, not a day either side of it.
      expect(stored.billDate, billDate);
      // Anything from the server is already synced.
      expect(stored.syncStatus, SyncStatus.synced);
    });

    test('a sale rebuilds its lines and settlement', () async {
      final sale = Sale(
        id: 'sale1',
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy1',
        saleDate: billDate,
        saleType: SaleType.detailed,
        totalAmount: Money.zero,
        items: [
          SaleItem(
            id: 'li1',
            saleId: 'sale1',
            description: 'Cotton',
            quantity: Quantity.fromWire('2.5'),
            unit: 'METER',
            unitPrice: Money.fromWire('800.00'),
          ),
          SaleItem(
            id: 'li2',
            saleId: 'sale1',
            description: 'Buttons',
            quantity: Quantity.fromWire('12'),
            unitPrice: Money.fromWire('5.00'),
          ),
        ],
        payments: [
          SalePayment(
            id: 'sp1',
            saleId: 'sale1',
            paymentMode: SalePaymentMode.credit,
            amount: Money.fromWire('2060.00'),
          ),
        ],
      ).recalculated;

      api.seedRemoteChange(DbTables.sale, SaleDto.toWire(sale));
      await engine.sync();

      final stored = (await SaleDao(db).byId('sale1'))!;
      expect(stored.items.length, 2);
      // Line order survives, which is why sortOrder exists at all.
      expect(stored.items.map((i) => i.description), ['Cotton', 'Buttons']);
      expect(stored.items.first.amount, Money.fromWire('2000.00'));
      expect(stored.subtotal, Money.fromWire('2060.00'));
      // Credit is a promise, not takings.
      expect(stored.settledTotal, Money.zero);
      expect(stored.dueTotal, Money.fromWire('2060.00'));
    });

    test('a cheque keeps its status and moves the balance correctly', () async {
      final payment = SupplierPayment(
        id: 'pay1',
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy1',
        supplierId: 's1',
        paymentDate: billDate,
        paymentMode: SupplierPaymentMode.cheque,
        amount: Money.fromWire('30000.00'),
        chequeNo: 'CHQ-99',
        chequeDate: billDate + 15 * 86400000,
        chequeDateBs: '2083-05-25',
        status: PaymentStatus.issued,
      );

      api.seedRemoteChange(DbTables.supplier, SupplierDto.toWire(supplier()));
      api.seedRemoteChange(
        DbTables.supplierPayment,
        SupplierPaymentDto.toWire(payment),
      );
      await engine.sync();

      final balance = (await SupplierDao(db).byId('s1'))!.balance!;
      expect(balance.uncleared, Money.fromWire('30000.00'));
      expect(balance.clearedTotal, Money.zero);
    });

    test('a tombstone removes the row from view', () async {
      api.seedRemoteChange(DbTables.supplier, SupplierDto.toWire(supplier()));
      await engine.sync();
      expect(await SupplierDao(db).byId('s1'), isNotNull);

      api.seedRemoteChange(
        DbTables.supplier,
        SupplierDto.toWire(
          supplier().copyWith(isDeleted: true, updatedAt: now + 1000),
        ),
      );
      cursors.cursors.clear();
      await engine.sync();

      // Gone from every query, but the row is still there to be re-pushed.
      expect(await SupplierDao(db).byId('s1'), isNull);
    });
  });

  group('a full round trip', () {
    test('what this device pushed comes back unchanged on another', () async {
      final record = supplier(opening: '1234.56');
      await saveLocally(
        entity: DbTables.supplier,
        id: record.id,
        row: record.toMap(),
        payload: record.toJson(),
      );
      await engine.sync();

      // A second device, starting empty, pulling the same server.
      final otherDb = await openTestDb();
      addTearDown(otherDb.close);
      final otherEngine = SyncEngine(
        api: api,
        queue: SyncQueueDao(otherDb),
        syncers: buildSyncers(otherDb),
        cursors: FakeCursorStore(),
        resolver: const ConflictResolver(deviceId: 'device-b'),
      );

      await otherEngine.sync();

      final landed = (await SupplierDao(otherDb).byId('s1'))!;
      expect(landed.name, 'ABC Textile');
      expect(landed.openingBalance, Money.fromWire('1234.56'));
      expect(landed.pan, '301234567');
      // The device that wrote it is echoed back, which is how the resolver
      // recognises its own changes.
      expect(landed.deviceId, deviceId);
    });

    test('the walk order is parents first', () {
      // A purchase references a fiscal year and a supplier; a sale references a
      // customer. Pull them the other way round and the children land first.
      expect(DbTables.syncable, [
        DbTables.fiscalYear,
        DbTables.supplier,
        DbTables.customer,
        DbTables.purchase,
        DbTables.supplierPayment,
        DbTables.sale,
      ]);
      expect(buildSyncers(db).map((s) => s.entity), DbTables.syncable);
    });
  });
}
