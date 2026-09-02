import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/utils/nepali_date.dart';
import 'package:billrecord/app/data/enums/payment_status.dart';
import 'package:billrecord/app/data/enums/sale_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/customer.dart';
import 'package:billrecord/app/data/models/fiscal_year.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/sale.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/providers/local/customer_dao.dart';
import 'package:billrecord/app/data/providers/local/fiscal_year_dao.dart';
import 'package:billrecord/app/data/providers/local/purchase_dao.dart';
import 'package:billrecord/app/data/providers/local/sale_dao.dart';
import 'package:billrecord/app/data/providers/local/supplier_dao.dart';
import 'package:billrecord/app/data/providers/local/supplier_payment_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// The supplier balance is derived from the documents rather than stored, on
/// this side and on the server's. These tests pin the arithmetic every payable
/// figure in the app depends on, against the rule in
/// `backend/src/modules/suppliers/supplier-balance.js`:
///
///     outstanding = opening balance + purchases − payments that are not cancelled
///
/// An issued cheque counts as paid — the shop has parted with it — and is also
/// reported separately as uncleared, because that money has not left the bank.
void main() {
  late Database db;
  late SupplierDao suppliers;
  late PurchaseDao purchases;
  late SupplierPaymentDao payments;
  late SaleDao sales;
  late FiscalYearDao years;
  late CustomerDao customers;

  const int day = 86400000;
  final int today = NepaliDate.toMs(DateTime.utc(2026, 9, 2));
  const int now = 1700000000000;

  setUp(() async {
    db = await openTestDb();
    suppliers = SupplierDao(db);
    purchases = PurchaseDao(db);
    payments = SupplierPaymentDao(db);
    sales = SaleDao(db);
    years = FiscalYearDao(db);
    customers = CustomerDao(db);

    await years.upsert(
      db,
      FiscalYear(
        id: 'fy',
        createdAt: now,
        updatedAt: now,
        name: '2083/84',
        startDate: NepaliDate.toMs(DateTime.utc(2026, 7, 17)),
        endDate: NepaliDate.toMs(DateTime.utc(2027, 7, 16)),
        isActive: true,
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> addSupplier(
    String id, {
    String name = 'ABC Textile',
    String opening = '0.00',
  }) =>
      suppliers.upsert(
        db,
        Supplier(
          id: id,
          createdAt: now,
          updatedAt: now,
          name: name,
          openingBalance: Money.fromWire(opening),
        ),
      );

  Future<void> addPurchase(
    String id, {
    String supplierId = 's1',
    required String amount,
    String? billNo,
    int? dateMs,
  }) =>
      purchases.upsert(
        db,
        Purchase(
          id: id,
          createdAt: now,
          updatedAt: now,
          fiscalYearId: 'fy',
          supplierId: supplierId,
          billNo: billNo ?? id,
          billDate: dateMs ?? today,
          amount: Money.fromWire(amount),
        ),
      );

  Future<void> addPayment(
    String id, {
    String supplierId = 's1',
    required String amount,
    PaymentStatus status = PaymentStatus.cleared,
    SupplierPaymentMode mode = SupplierPaymentMode.cash,
    int? dateMs,
    int? chequeDateMs,
    String? purchaseId,
  }) =>
      payments.upsert(
        db,
        SupplierPayment(
          id: id,
          createdAt: now,
          updatedAt: now,
          fiscalYearId: 'fy',
          supplierId: supplierId,
          purchaseId: purchaseId,
          paymentDate: dateMs ?? today,
          paymentMode: mode,
          amount: Money.fromWire(amount),
          chequeNo: mode.isCheque ? 'CHQ-$id' : null,
          chequeDate: chequeDateMs,
          status: status,
        ),
      );

  Future<void> addSale(String id, {required String total, int? dateMs}) =>
      sales.upsert(
        db,
        Sale(
          id: id,
          createdAt: now,
          updatedAt: now,
          fiscalYearId: 'fy',
          saleDate: dateMs ?? today,
          saleType: SaleType.summary,
          totalAmount: Money.fromWire(total),
        ),
      );

  group('the derived supplier balance', () {
    test('is opening plus bills less payments', () async {
      await addSupplier('s1', opening: '5000.00');
      await addPurchase('p1', amount: '100000.00');
      await addPayment('pay1', amount: '20000.00');

      final balance = (await suppliers.byId('s1'))!.balance!;

      expect(balance.openingBalance, Money.fromWire('5000.00'));
      expect(balance.purchaseTotal, Money.fromWire('100000.00'));
      expect(balance.outstanding, Money.fromWire('85000.00'));
      expect(balance.billCount, 1);
      expect(balance.paymentCount, 1);
    });

    test('an issued cheque counts as paid but stays uncleared', () async {
      await addSupplier('s1');
      await addPurchase('p1', amount: '100000.00');
      await addPayment('pay1', amount: '20000.00');
      await addPayment(
        'pay2',
        amount: '30000.00',
        mode: SupplierPaymentMode.cheque,
        status: PaymentStatus.issued,
        chequeDateMs: today + 15 * day,
      );

      final balance = (await suppliers.byId('s1'))!.balance!;

      // The shop has parted with the cheque, so the liability is down to 50k.
      expect(balance.paidTotal, Money.fromWire('50000.00'));
      expect(balance.outstanding, Money.fromWire('50000.00'));
      // But the money has not left the bank.
      expect(balance.clearedTotal, Money.fromWire('20000.00'));
      expect(balance.uncleared, Money.fromWire('30000.00'));
    });

    test('a cancelled payment settles nothing', () async {
      await addSupplier('s1');
      await addPurchase('p1', amount: '100000.00');
      await addPayment('pay1', amount: '40000.00');
      await addPayment(
        'pay2',
        amount: '30000.00',
        mode: SupplierPaymentMode.cheque,
        status: PaymentStatus.cancelled,
      );

      final balance = (await suppliers.byId('s1'))!.balance!;

      expect(balance.outstanding, Money.fromWire('60000.00'));
      expect(balance.paidTotal, Money.fromWire('40000.00'));
      // A bounced cheque is not a payment at all, so it is not even counted.
      expect(balance.paymentCount, 1);
    });

    test('a voided bill stops counting', () async {
      await addSupplier('s1');
      await addPurchase('p1', amount: '100000.00');
      await addPurchase('p2', amount: '25000.00');
      await db.update('purchases', {'is_deleted': 1},
          where: 'id = ?', whereArgs: ['p2']);

      final balance = (await suppliers.byId('s1'))!.balance!;
      expect(balance.purchaseTotal, Money.fromWire('100000.00'));
      expect(balance.billCount, 1);
    });

    test('a supplier with nothing recorded is zero, not null', () async {
      await addSupplier('s1');
      final balance = (await suppliers.byId('s1'))!.balance!;
      expect(balance.outstanding, Money.zero);
      expect(balance.isSettled, isTrue);
    });

    test('summing many bills does not drift', () async {
      await addSupplier('s1');
      for (var i = 0; i < 300; i += 1) {
        await addPurchase('p$i', amount: '0.07', billNo: 'b$i');
      }
      final balance = (await suppliers.byId('s1'))!.balance!;
      expect(balance.purchaseTotal, Money.fromWire('21.00'));
    });
  });

  group('payable across every supplier', () {
    setUp(() async {
      await addSupplier('s1', name: 'ABC Textile');
      await addSupplier('s2', name: 'XYZ Fabrics');
      await addSupplier('s3', name: 'Settled Traders');

      await addPurchase('p1', supplierId: 's1', amount: '100000.00');
      await addPurchase('p2', supplierId: 's2', amount: '40000.00');
      await addPurchase('p3', supplierId: 's3', amount: '10000.00');
      await addPayment('pay3', supplierId: 's3', amount: '10000.00');
    });

    test('totals only what is actually owed', () async {
      final payable = await suppliers.payable();
      expect(payable.total, Money.fromWire('140000.00'));
      // The settled supplier is not counted.
      expect(payable.supplierCount, 2);
    });

    test('ranks the biggest exposure first', () async {
      final top = await suppliers.topOutstanding();
      expect(top.map((s) => s.name), ['ABC Textile', 'XYZ Fabrics']);
      expect(top.first.balance!.outstanding, Money.fromWire('100000.00'));
    });

    test('the list itself leads with what is owed', () async {
      // The supplier list is a payables worklist, not an address book.
      final all = await suppliers.all();
      expect(all.first.name, 'ABC Textile');
      expect(all.last.name, 'Settled Traders');
    });
  });

  group('the cheque register', () {
    test('is ordered by the date on the cheque, not the day handed over',
        () async {
      await addSupplier('s1');
      // Handed over first, but dated latest.
      await addPayment('early',
          amount: '1000.00',
          mode: SupplierPaymentMode.cheque,
          status: PaymentStatus.issued,
          dateMs: today,
          chequeDateMs: today + 30 * day);
      await addPayment('late',
          amount: '2000.00',
          mode: SupplierPaymentMode.cheque,
          status: PaymentStatus.issued,
          dateMs: today + 5 * day,
          chequeDateMs: today + 10 * day);

      expect((await payments.chequeRegister()).map((p) => p.id),
          ['late', 'early']);
    });

    test('leaves out cheques that have already gone through', () async {
      await addSupplier('s1');
      await addPayment('pending',
          amount: '1000.00',
          mode: SupplierPaymentMode.cheque,
          status: PaymentStatus.issued,
          chequeDateMs: today + day);
      await addPayment('done',
          amount: '2000.00',
          mode: SupplierPaymentMode.cheque,
          status: PaymentStatus.cleared,
          chequeDateMs: today + 2 * day);
      await addPayment('bounced',
          amount: '3000.00',
          mode: SupplierPaymentMode.cheque,
          status: PaymentStatus.cancelled,
          chequeDateMs: today + 3 * day);

      expect((await payments.chequeRegister()).map((p) => p.id), ['pending']);
      // Everything, when the caller asks for the full history.
      expect((await payments.chequeRegister(onlyPending: false)).length, 3);
    });

    test('ignores cash and transfers entirely', () async {
      await addSupplier('s1');
      await addPayment('cash', amount: '1000.00');
      await addPayment('transfer',
          amount: '2000.00', mode: SupplierPaymentMode.bankTransfer);

      expect(await payments.chequeRegister(), isEmpty);
    });

    test('uncleared totals what is promised but still in the account',
        () async {
      await addSupplier('s1');
      await addPayment('c1',
          amount: '30000.00',
          mode: SupplierPaymentMode.cheque,
          status: PaymentStatus.issued);
      await addPayment('c2',
          amount: '5000.00',
          mode: SupplierPaymentMode.cheque,
          status: PaymentStatus.cleared);

      final uncleared = await payments.uncleared();
      expect(uncleared.total, Money.fromWire('30000.00'));
      expect(uncleared.count, 1);
    });
  });

  group('what is still owed on one bill', () {
    test('paid total counts an issued cheque, not a cancelled one', () async {
      await addSupplier('s1');
      await addPurchase('bill', amount: '100000.00');
      await addPayment('a',
          amount: '20000.00', purchaseId: 'bill');
      await addPayment('b',
          amount: '30000.00',
          mode: SupplierPaymentMode.cheque,
          status: PaymentStatus.issued,
          purchaseId: 'bill');
      await addPayment('c',
          amount: '9999.00',
          status: PaymentStatus.cancelled,
          purchaseId: 'bill');

      final bill = (await purchases.byId('bill'))!;
      expect(bill.paidTotal, Money.fromWire('50000.00'));
      expect(bill.dueTotal, Money.fromWire('50000.00'));
      expect(bill.isFullyPaid, isFalse);
    });

    test('a payment against the running balance is not tied to a bill',
        () async {
      await addSupplier('s1');
      await addPurchase('bill', amount: '5000.00');
      // No purchaseId: settles the supplier's general position.
      await addPayment('loose', amount: '5000.00');

      final bill = (await purchases.byId('bill'))!;
      expect(bill.paidTotal, Money.zero);
      // ...but the supplier is square.
      expect((await suppliers.byId('s1'))!.balance!.outstanding, Money.zero);
    });

    test('the supplier name is joined in for the row', () async {
      await addSupplier('s1', name: 'ABC Textile');
      await addPurchase('bill', amount: '100.00');
      expect((await purchases.byId('bill'))!.supplierName, 'ABC Textile');
    });
  });

  group('sales by day', () {
    test('groups and totals, newest first', () async {
      await addSale('a', total: '1000.00', dateMs: today);
      await addSale('b', total: '2000.00', dateMs: today);
      await addSale('c', total: '500.00', dateMs: today - day);

      final days = await sales.byDay();
      expect(days.length, 2);
      expect(days.first.dateMs, today);
      expect(days.first.total, Money.fromWire('3000.00'));
      expect(days.first.count, 2);
      expect(days.last.total, Money.fromWire('500.00'));
    });

    test('the day book returns the day in full', () async {
      await addSale('a', total: '1000.00', dateMs: today);
      await addSale('b', total: '2000.00', dateMs: today);
      await addSale('c', total: '500.00', dateMs: today - day);

      final book = await sales.dayBook(today);
      expect(book.count, 2);
      expect(book.total, Money.fromWire('3000.00'));
      expect(book.sales.map((s) => s.id).toSet(), {'a', 'b'});
    });

    test('an empty day is empty, not an error', () async {
      final book = await sales.dayBook(today);
      expect(book.count, 0);
      expect(book.total, Money.zero);
    });

    test('daily totals skip the quiet days, for the caller to fill', () async {
      await addSale('a', total: '1000.00', dateMs: today);
      await addSale('b', total: '500.00', dateMs: today - 3 * day);

      final totals = await sales.dailyTotals(today - 6 * day, today);
      expect(totals.keys.toSet(), {today, today - 3 * day});
    });
  });

  group('customers', () {
    test('carry their invoice count and total', () async {
      await customers.upsert(
        db,
        Customer(id: 'c1', createdAt: now, updatedAt: now, name: 'Sita'),
      );
      await sales.upsert(
        db,
        Sale(
          id: 's-1',
          createdAt: now,
          updatedAt: now,
          fiscalYearId: 'fy',
          customerId: 'c1',
          saleDate: today,
          saleType: SaleType.detailed,
          totalAmount: Money.fromWire('4000.00'),
        ),
      );

      final customer = (await customers.byId('c1'))!;
      expect(customer.saleCount, 1);
      expect(customer.saleTotal, Money.fromWire('4000.00'));
    });

    test('a customer with no invoices reads zero, not null', () async {
      await customers.upsert(
        db,
        Customer(id: 'c1', createdAt: now, updatedAt: now, name: 'Sita'),
      );
      final customer = (await customers.byId('c1'))!;
      expect(customer.saleCount, 0);
      expect(customer.saleTotal, Money.zero);
    });
  });

  group('fiscal years', () {
    test('a back-dated document finds the year that contains its date',
        () async {
      // Not the active year, which is what a naive form would use.
      final inRange = NepaliDate.toMs(DateTime.utc(2026, 9, 1));
      final outOfRange = NepaliDate.toMs(DateTime.utc(2025, 1, 1));

      expect((await years.covering(inRange))!.name, '2083/84');
      expect(await years.covering(outOfRange), isNull);
    });

    test('the active year is the one new records are filed under', () async {
      expect((await years.active())!.name, '2083/84');
    });

    test('a year with documents against it refuses deletion', () async {
      await addSupplier('s1');
      await addPurchase('p1', amount: '100.00');
      expect(await years.hasTransactions('fy'), isTrue);
    });
  });
}
