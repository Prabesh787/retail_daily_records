import 'package:billrecord/app/core/constants/db_constants.dart';
import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/utils/nepali_date.dart';
import 'package:billrecord/app/data/enums/payment_status.dart';
import 'package:billrecord/app/data/enums/sale_payment_mode.dart';
import 'package:billrecord/app/data/enums/sale_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/customer.dart';
import 'package:billrecord/app/data/models/fiscal_year.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/sale.dart';
import 'package:billrecord/app/data/models/sale_item.dart';
import 'package:billrecord/app/data/models/sale_payment.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// The schema lives in `createTableSql` strings, which the Dart analyzer cannot
/// check. These tests execute them, so a typo in a column list or a foreign key
/// is a failing test rather than a crash on a shopkeeper's phone the first time
/// they save a bill.
void main() {
  late Database db;

  const int day = 86400000;
  final int billDate = NepaliDate.toMs(DateTime.utc(2026, 8, 17));
  const int now = 1700000000000;

  setUp(() async => db = await openTestDb());
  tearDown(() async => db.close());

  FiscalYear year({String id = 'fy-1', String name = '2083/84'}) => FiscalYear(
        id: id,
        createdAt: now,
        updatedAt: now,
        name: name,
        startDate: NepaliDate.toMs(DateTime.utc(2026, 7, 17)),
        endDate: NepaliDate.toMs(DateTime.utc(2027, 7, 16)),
        startDateBs: '2083-04-01',
        endDateBs: '2084-03-31',
        isActive: true,
      );

  Supplier supplier({String id = 'sup-1', String name = 'ABC Textile'}) =>
      Supplier(
        id: id,
        createdAt: now,
        updatedAt: now,
        name: name,
        openingBalance: Money.fromWire('5000.00'),
        pan: '301234567',
      );

  Purchase purchase({
    String id = 'pur-1',
    String billNo = '4521',
    String supplierId = 'sup-1',
    String amount = '100000.00',
  }) =>
      Purchase(
        id: id,
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy-1',
        supplierId: supplierId,
        billNo: billNo,
        billDate: billDate,
        billDateBs: '2083-05-01',
        amount: Money.fromWire(amount),
      );

  Future<void> seedMasters() async {
    await db.insert(DbTables.fiscalYear, year().toMap());
    await db.insert(DbTables.supplier, supplier().toMap());
  }

  group('the schema builds and accepts a full record', () {
    test('every table exists', () async {
      final names = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
          .map((r) => r['name'] as String)
          .toSet();

      expect(
        names,
        containsAll([
          DbTables.fiscalYear,
          DbTables.supplier,
          DbTables.customer,
          DbTables.purchase,
          DbTables.supplierPayment,
          DbTables.sale,
          DbTables.saleItem,
          DbTables.salePayment,
          DbTables.syncQueue,
        ]),
      );
    });

    test('a purchase round trips through SQLite unchanged', () async {
      await seedMasters();
      await db.insert(DbTables.purchase, purchase().toMap());

      final read = Purchase.fromMap((await db.query(DbTables.purchase)).single);

      expect(read.billNo, '4521');
      expect(read.amount, Money.fromWire('100000.00'));
      expect(read.billDateBs, '2083-05-01');
      expect(read.billDate, billDate);
    });

    test('a supplier payment keeps its cheque details and status', () async {
      await seedMasters();

      await db.insert(
        DbTables.supplierPayment,
        SupplierPayment(
          id: 'pay-1',
          createdAt: now,
          updatedAt: now,
          fiscalYearId: 'fy-1',
          supplierId: 'sup-1',
          voucherNo: 'V-001',
          paymentDate: billDate,
          paymentDateBs: '2083-05-01',
          paymentMode: SupplierPaymentMode.cheque,
          amount: Money.fromWire('30000.00'),
          chequeNo: 'CHQ-99',
          chequeDate: billDate + 15 * day,
          chequeDateBs: '2083-05-25',
          status: PaymentStatus.issued,
        ).toMap(),
      );

      final read =
          SupplierPayment.fromMap((await db.query(DbTables.supplierPayment)).single);

      expect(read.paymentMode, SupplierPaymentMode.cheque);
      expect(read.status, PaymentStatus.issued);
      expect(read.chequeNo, 'CHQ-99');
      // An issued cheque counts as paid but is still uncleared.
      expect(read.recognisedAmount, Money.fromWire('30000.00'));
      expect(read.unclearedAmount, Money.fromWire('30000.00'));
      // The register sorts on the date written on the cheque.
      expect(read.dueDate, billDate + 15 * day);
    });

    test('an itemised sale stores its lines and settlement', () async {
      await db.insert(DbTables.fiscalYear, year().toMap());
      await db.insert(
        DbTables.customer,
        Customer(id: 'cus-1', createdAt: now, updatedAt: now, name: 'Sita')
            .toMap(),
      );

      final sale = Sale(
        id: 'sale-1',
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy-1',
        invoiceNo: 'A-0012',
        saleDate: billDate,
        saleDateBs: '2083-05-01',
        customerId: 'cus-1',
        saleType: SaleType.detailed,
        totalAmount: Money.zero,
        items: [
          SaleItem(
            id: 'li-1',
            saleId: 'sale-1',
            description: 'Printed Cotton - Blue',
            quantity: Quantity.fromWire('5'),
            unit: 'METER',
            unitPrice: Money.fromWire('800.00'),
          ),
        ],
        payments: [
          SalePayment(
            id: 'sp-1',
            saleId: 'sale-1',
            paymentMode: SalePaymentMode.cash,
            amount: Money.fromWire('4000.00'),
          ),
        ],
      ).recalculated;

      await db.insert(DbTables.sale, sale.toMap());
      for (final item in sale.items) {
        await db.insert(DbTables.saleItem, item.toMap());
      }
      for (final payment in sale.payments) {
        await db.insert(DbTables.salePayment, payment.toMap());
      }

      final read = Sale.fromMap(
        (await db.query(DbTables.sale)).single,
        items: (await db.query(DbTables.saleItem, orderBy: 'sort_order'))
            .map(SaleItem.fromMap)
            .toList(),
        payments: (await db.query(DbTables.salePayment))
            .map(SalePayment.fromMap)
            .toList(),
      );

      expect(read.items.single.amount, Money.fromWire('4000.00'));
      expect(read.subtotal, Money.fromWire('4000.00'));
      expect(read.settledTotal, Money.fromWire('4000.00'));
      expect(read.dueTotal, Money.zero);
      expect(read.isFullyPaid, isTrue);
    });

    test('deleting a sale takes its lines with it', () async {
      await db.insert(DbTables.fiscalYear, year().toMap());
      await db.insert(
        DbTables.sale,
        Sale(
          id: 'sale-1',
          createdAt: now,
          updatedAt: now,
          fiscalYearId: 'fy-1',
          saleDate: billDate,
          saleType: SaleType.summary,
          totalAmount: Money.fromWire('4050.00'),
        ).toMap(),
      );
      await db.insert(
        DbTables.saleItem,
        SaleItem(
          id: 'li-1',
          saleId: 'sale-1',
          description: 'x',
          quantity: Quantity.fromWire('1'),
          unitPrice: Money.fromWire('1.00'),
        ).toMap(),
      );

      await db.delete(DbTables.sale, where: 'id = ?', whereArgs: ['sale-1']);

      expect(await db.query(DbTables.saleItem), isEmpty);
    });
  });

  group('the constraints that matter', () {
    test('two suppliers may both issue bill 4521', () async {
      await seedMasters();
      await db.insert(
        DbTables.supplier,
        supplier(id: 'sup-2', name: 'XYZ Fabrics').toMap(),
      );

      await db.insert(DbTables.purchase, purchase().toMap());
      await db.insert(
        DbTables.purchase,
        purchase(id: 'pur-2', supplierId: 'sup-2').toMap(),
      );

      expect((await db.query(DbTables.purchase)).length, 2);
    });

    test('the same supplier cannot issue bill 4521 twice in a year', () async {
      await seedMasters();
      await db.insert(DbTables.purchase, purchase().toMap());

      expect(
        () => db.insert(DbTables.purchase, purchase(id: 'pur-2').toMap()),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('a voided bill number can be reused, because the index is partial',
        () async {
      await seedMasters();
      await db.insert(DbTables.purchase, purchase().toMap());
      await db.update(
        DbTables.purchase,
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: ['pur-1'],
      );

      await db.insert(DbTables.purchase, purchase(id: 'pur-2').toMap());
      expect((await db.query(DbTables.purchase)).length, 2);
    });

    test('summary sales may all have no invoice number', () async {
      await db.insert(DbTables.fiscalYear, year().toMap());
      for (var i = 0; i < 3; i += 1) {
        await db.insert(
          DbTables.sale,
          Sale(
            id: 'sale-$i',
            createdAt: now,
            updatedAt: now,
            fiscalYearId: 'fy-1',
            saleDate: billDate,
            saleType: SaleType.summary,
            totalAmount: Money.fromWire('100.00'),
          ).toMap(),
        );
      }
      expect((await db.query(DbTables.sale)).length, 3);
    });

    test('an invoice number cannot repeat within a fiscal year', () async {
      await db.insert(DbTables.fiscalYear, year().toMap());
      Sale invoiced(String id) => Sale(
            id: id,
            createdAt: now,
            updatedAt: now,
            fiscalYearId: 'fy-1',
            invoiceNo: 'A-0012',
            saleDate: billDate,
            saleType: SaleType.detailed,
            totalAmount: Money.fromWire('100.00'),
          );

      await db.insert(DbTables.sale, invoiced('sale-1').toMap());
      expect(
        () => db.insert(DbTables.sale, invoiced('sale-2').toMap()),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('a purchase may arrive before the supplier it belongs to', () async {
      // Deliberately no foreign key across entities. Once sync is on, a pulled
      // row can arrive before its parent; with the constraint on, that insert
      // throws, the engine skips the row and the cursor moves past it — and the
      // bill is lost with nothing to say so.
      await db.insert(DbTables.purchase, purchase().toMap());
      expect((await db.query(DbTables.purchase)).length, 1);
    });

    test('a sale line still cannot exist without its sale', () async {
      // The one foreign key that stays: a sale and its lines are written
      // together in a single transaction as one document, so there is no
      // ordering problem here to lose data to.
      expect(
        () => db.insert(
          DbTables.saleItem,
          SaleItem(
            id: 'orphan',
            saleId: 'no-such-sale',
            description: 'x',
            quantity: Quantity.fromWire('1'),
            unitPrice: Money.fromWire('1.00'),
          ).toMap(),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('derived figures', () {
    test('outstanding is opening plus purchases less recognised payments', () {
      const balance = SupplierBalance(
        openingBalance: Money.fromPaisa(500000), // 5,000.00
        purchaseTotal: Money.fromPaisa(10000000), // 100,000.00
        clearedTotal: Money.fromPaisa(2000000), // 20,000.00
        uncleared: Money.fromPaisa(3000000), // 30,000.00
      );

      // The issued cheque counts as paid — the shop has parted with it.
      expect(balance.paidTotal, Money.fromWire('50000.00'));
      expect(balance.outstanding, Money.fromWire('55000.00'));
    });

    test('a cancelled payment settles nothing', () {
      expect(PaymentStatus.cancelled.reducesLiability, isFalse);
      expect(PaymentStatus.issued.reducesLiability, isTrue);
      expect(PaymentStatus.cleared.reducesLiability, isTrue);
    });

    test('credit taken on a sale is not takings', () {
      expect(
        SalePayment(
          id: 'sp-1',
          saleId: 'sale-1',
          paymentMode: SalePaymentMode.credit,
          amount: Money.fromWire('4000.00'),
        ).settledAmount,
        Money.zero,
      );
    });

    test('a summary sale derives nothing from lines it does not have', () {
      final sale = Sale(
        id: 'sale-1',
        createdAt: 0,
        updatedAt: 0,
        fiscalYearId: 'fy-1',
        saleDate: billDate,
        saleType: SaleType.summary,
        totalAmount: Money.fromWire('4050.00'),
      ).recalculated;

      expect(sale.totalAmount, Money.fromWire('4050.00'));
      expect(sale.subtotal, Money.fromWire('4050.00'));
    });

    test('an itemised total is its lines less the header discount', () {
      final sale = Sale(
        id: 'sale-1',
        createdAt: 0,
        updatedAt: 0,
        fiscalYearId: 'fy-1',
        saleDate: billDate,
        saleType: SaleType.detailed,
        discount: Money.fromWire('50.00'),
        totalAmount: Money.fromWire('999999.00'), // whatever a form sent
        items: [
          SaleItem(
            id: 'li-1',
            saleId: 'sale-1',
            description: 'a',
            quantity: Quantity.fromWire('2.5'),
            unitPrice: Money.fromWire('800.00'),
          ),
          SaleItem(
            id: 'li-2',
            saleId: 'sale-1',
            description: 'b',
            quantity: Quantity.fromWire('3'),
            unitPrice: Money.fromWire('333.33'),
            discount: Money.fromWire('0.99'),
          ),
        ],
      ).recalculated;

      expect(sale.subtotal, Money.fromWire('2999.00'));
      expect(sale.totalAmount, Money.fromWire('2949.00'));
    });

    test('cancelling a payment unsets its cleared date', () {
      final cleared = SupplierPayment(
        id: 'pay-1',
        createdAt: now,
        updatedAt: now,
        fiscalYearId: 'fy-1',
        supplierId: 'sup-1',
        paymentDate: billDate,
        paymentMode: SupplierPaymentMode.cheque,
        amount: Money.fromWire('100.00'),
        clearedDate: billDate,
      );

      // `copyWith(clearedDate: null)` cannot express this - it is
      // indistinguishable from not passing the argument at all.
      final cancelled = cleared.copyWith(
        status: PaymentStatus.cancelled,
        clearClearedDate: true,
      );

      expect(cancelled.clearedDate, isNull);
      expect(cancelled.recognisedAmount, Money.zero);
    });
  });

  group('the wire payload', () {
    test('a sale carries its lines and payments, so it syncs atomically', () {
      final json = Sale(
        id: 'sale-1',
        createdAt: 1,
        updatedAt: 2,
        fiscalYearId: 'fy-1',
        saleDate: billDate,
        saleDateBs: '2083-05-01',
        saleType: SaleType.detailed,
        totalAmount: Money.fromWire('4000.00'),
        items: [
          SaleItem(
            id: 'li-1',
            saleId: 'sale-1',
            description: 'Printed Cotton',
            quantity: Quantity.fromWire('5'),
            unit: 'METER',
            unitPrice: Money.fromWire('800.00'),
          ),
        ],
        payments: [
          SalePayment(
            id: 'sp-1',
            saleId: 'sale-1',
            paymentMode: SalePaymentMode.cash,
            amount: Money.fromWire('4000.00'),
          ),
        ],
      ).toJson();

      expect((json['items'] as List).single['amount'], '4000.00');
      expect((json['payments'] as List).single['paymentMode'], 'CASH');
      // Document dates go out as AD ISO with the BS string beside them, the way
      // the REST serializers already send them.
      expect(json['saleDate'], '2026-08-17');
      expect(json['saleDateBs'], '2083-05-01');
      // Sync metadata keeps the snake_case names SyncEngine reads.
      expect(json['updated_at'], 2);
      expect(json['is_deleted'], false);
    });

    test('money goes out as a fixed-precision string, never a number', () {
      final json = purchase(amount: '100000.00').toJson();
      expect(json['amount'], '100000.00');
      expect(json['amount'], isA<String>());
      expect(json['billDate'], '2026-08-17');
    });
  });
}
