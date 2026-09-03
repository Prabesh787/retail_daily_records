import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/utils/nepali_date.dart';
import 'package:billrecord/app/data/enums/payment_status.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/fiscal_year.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/providers/local/fiscal_year_dao.dart';
import 'package:billrecord/app/data/providers/local/purchase_dao.dart';
import 'package:billrecord/app/data/providers/local/supplier_dao.dart';
import 'package:billrecord/app/data/providers/local/supplier_payment_dao.dart';
import 'package:billrecord/app/data/repositories/supplier_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_db.dart';

/// A supplier statement over one date window.
///
/// Two things are being pinned here, and they fail in different ways.
///
/// The **window query** answers "what was owed on the morning of the 1st",
/// which the all-time balance cannot. Get it wrong and the statement's opening
/// balance is silently the wrong number — the movements underneath are still
/// right, so nothing looks broken; the total is just not what the supplier's
/// own books say.
///
/// The **running balance** walks those movements from that opening. Its
/// contract is that the last line equals the closing figure in the header. If
/// those two ever disagree, one of them is lying, and a shopkeeper reconciling
/// against a supplier has no way to tell which.
void main() {
  late Database db;
  late SupplierDao suppliers;
  late PurchaseDao purchases;
  late SupplierPaymentDao payments;

  const int day = 86400000;
  const int now = 1700000000000;

  // A window over August, with movements on either side of both bounds.
  final int julyEnd = NepaliDate.toMs(DateTime.utc(2026, 7, 28));
  final int augStart = NepaliDate.toMs(DateTime.utc(2026, 8, 1));
  final int augMid = NepaliDate.toMs(DateTime.utc(2026, 8, 14));
  final int augEnd = NepaliDate.toMs(DateTime.utc(2026, 8, 31));
  final int sept = NepaliDate.toMs(DateTime.utc(2026, 9, 4));

  setUp(() async {
    db = await openTestDb();
    suppliers = SupplierDao(db);
    purchases = PurchaseDao(db);
    payments = SupplierPaymentDao(db);

    await FiscalYearDao(db).upsert(
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

  Future<void> addSupplier({String opening = '0.00'}) => suppliers.upsert(
    db,
    Supplier(
      id: 's1',
      createdAt: now,
      updatedAt: now,
      name: 'ABC Textile',
      openingBalance: Money.fromWire(opening),
    ),
  );

  Future<void> addBill(String id, String amount, int dateMs) => purchases.upsert(
    db,
    Purchase(
      id: id,
      createdAt: now,
      updatedAt: now,
      fiscalYearId: 'fy',
      supplierId: 's1',
      billNo: id.toUpperCase(),
      billDate: dateMs,
      amount: Money.fromWire(amount),
    ),
  );

  Future<void> addPayment(
    String id,
    String amount,
    int dateMs, {
    PaymentStatus status = PaymentStatus.cleared,
    SupplierPaymentMode mode = SupplierPaymentMode.cash,
  }) => payments.upsert(
    db,
    SupplierPayment(
      id: id,
      createdAt: now,
      updatedAt: now,
      fiscalYearId: 'fy',
      supplierId: 's1',
      paymentDate: dateMs,
      paymentMode: mode,
      amount: Money.fromWire(amount),
      chequeNo: mode.isCheque ? 'CHQ-$id' : null,
      chequeDate: mode.isCheque ? dateMs + 20 * day : null,
      status: status,
    ),
  );

  group('the window query', () {
    test('carries in what was owed before the window opened', () async {
      await addSupplier(opening: '5000.00');
      await addBill('b1', '40000.00', julyEnd); // before
      await addPayment('p1', '10000.00', julyEnd); // before
      await addBill('b2', '25000.00', augMid); // inside

      final window = await suppliers.window(
        's1',
        fromMs: augStart,
        toMs: augEnd,
      );

      // 5,000 opening + 40,000 billed − 10,000 paid, all before 1 August.
      expect(window.openingAsOf, Money.fromWire('35000.00'));
      expect(window.purchaseTotal, Money.fromWire('25000.00'));
      expect(window.billCount, 1);
      expect(window.closing, Money.fromWire('60000.00'));
    });

    test('excludes movements after the window closes', () async {
      await addSupplier();
      await addBill('b1', '10000.00', augMid);
      await addBill('b2', '99000.00', sept);
      await addPayment('p1', '4000.00', sept);

      final window = await suppliers.window(
        's1',
        fromMs: augStart,
        toMs: augEnd,
      );

      expect(window.purchaseTotal, Money.fromWire('10000.00'));
      expect(window.paymentTotal, Money.zero);
      expect(window.closing, Money.fromWire('10000.00'));
    });

    test('an unbounded window opens at the opening balance', () async {
      await addSupplier(opening: '5000.00');
      await addBill('b1', '40000.00', julyEnd);
      await addBill('b2', '25000.00', augMid);
      await addPayment('p1', '30000.00', sept);

      final window = await suppliers.window('s1');

      // Nothing is "before" a window with no start, so nothing is carried in
      // beyond the opening balance itself.
      expect(window.openingAsOf, Money.fromWire('5000.00'));
      expect(window.purchaseTotal, Money.fromWire('65000.00'));
      expect(window.paymentTotal, Money.fromWire('30000.00'));
      expect(window.closing, Money.fromWire('40000.00'));

      // And it agrees with the all-time balance, which is computed by an
      // entirely different query.
      final balance = (await suppliers.byId('s1'))!.balance!;
      expect(window.closing, balance.outstanding);
    });

    test('an issued cheque is paid, and also reported as uncleared', () async {
      await addSupplier();
      await addBill('b1', '100000.00', augMid);
      await addPayment('p1', '20000.00', augMid);
      await addPayment(
        'p2',
        '30000.00',
        augMid,
        mode: SupplierPaymentMode.cheque,
        status: PaymentStatus.issued,
      );

      final window = await suppliers.window(
        's1',
        fromMs: augStart,
        toMs: augEnd,
      );

      expect(window.paymentTotal, Money.fromWire('50000.00'));
      expect(window.unclearedTotal, Money.fromWire('30000.00'));
      expect(window.closing, Money.fromWire('50000.00'));
    });

    test('a cancelled payment settles nothing but is still counted', () async {
      await addSupplier();
      await addBill('b1', '100000.00', augMid);
      await addPayment('p1', '20000.00', augMid);
      await addPayment(
        'p2',
        '15000.00',
        augMid,
        status: PaymentStatus.cancelled,
      );

      final window = await suppliers.window(
        's1',
        fromMs: augStart,
        toMs: augEnd,
      );

      expect(window.paymentTotal, Money.fromWire('20000.00'));
      // Counted, because the statement lists it for the audit trail.
      expect(window.paymentCount, 2);
      expect(window.closing, Money.fromWire('80000.00'));
    });

    test('a bill dated exactly on a bound is inside the window', () async {
      await addSupplier();
      await addBill('b1', '1000.00', augStart);
      await addBill('b2', '2000.00', augEnd);

      final window = await suppliers.window(
        's1',
        fromMs: augStart,
        toMs: augEnd,
      );

      // Inclusive bounds — an off-by-one here drops a real day's trading off
      // the end of every monthly statement.
      expect(window.billCount, 2);
      expect(window.purchaseTotal, Money.fromWire('3000.00'));
    });
  });

  group('the running balance', () {
    SupplierStatement statementOf({
      required Money openingAsOf,
      List<Purchase> bills = const [],
      List<SupplierPayment> paid = const [],
    }) => SupplierStatement(
      supplier: Supplier(id: 's1', createdAt: now, updatedAt: now, name: 'ABC'),
      window: SupplierWindow(
        openingAsOf: openingAsOf,
        purchaseTotal: Money.sum(bills.map((b) => b.amount)),
        paymentTotal: Money.sum(paid.map((p) => p.recognisedAmount)),
        billCount: bills.length,
        paymentCount: paid.length,
      ),
      purchases: bills,
      payments: paid,
    );

    Purchase bill(String id, String amount, int dateMs) => Purchase(
      id: id,
      createdAt: now,
      updatedAt: now,
      fiscalYearId: 'fy',
      supplierId: 's1',
      billNo: id.toUpperCase(),
      billDate: dateMs,
      amount: Money.fromWire(amount),
    );

    SupplierPayment payment(
      String id,
      String amount,
      int dateMs, {
      PaymentStatus status = PaymentStatus.cleared,
    }) => SupplierPayment(
      id: id,
      createdAt: now,
      updatedAt: now,
      fiscalYearId: 'fy',
      supplierId: 's1',
      paymentDate: dateMs,
      paymentMode: SupplierPaymentMode.cash,
      amount: Money.fromWire(amount),
      status: status,
    );

    test('ends on the closing balance in the header', () async {
      final statement = statementOf(
        openingAsOf: Money.fromWire('35000.00'),
        bills: [bill('b1', '25000.00', augMid)],
        paid: [payment('p1', '10000.00', augEnd)],
      );

      final lines = statement.lines;

      expect(lines.length, 2);
      expect(lines.last.balance, statement.window.closing);
      expect(lines.last.balance, Money.fromWire('50000.00'));
    });

    test('runs oldest first, from the balance carried in', () async {
      final statement = statementOf(
        openingAsOf: Money.fromWire('1000.00'),
        bills: [
          bill('b1', '4000.00', augStart),
          bill('b2', '2000.00', augEnd),
        ],
        paid: [payment('p1', '3000.00', augMid)],
      );

      final lines = statement.lines;

      expect(lines.map((line) => line.reference).toList(), [
        'Bill B1',
        'Cash',
        'Bill B2',
      ]);
      expect(lines[0].balance, Money.fromWire('5000.00'));
      expect(lines[1].balance, Money.fromWire('2000.00'));
      expect(lines[2].balance, Money.fromWire('4000.00'));
    });

    test('a cancelled payment is listed but moves nothing', () async {
      final statement = statementOf(
        openingAsOf: Money.fromWire('10000.00'),
        paid: [
          payment('p1', '4000.00', augStart, status: PaymentStatus.cancelled),
          payment('p2', '1000.00', augEnd),
        ],
      );

      final lines = statement.lines;

      expect(lines.length, 2);
      // The bounced cheque is on the statement, and the balance beside it is
      // unchanged from the one carried in.
      expect(lines.first.credit, Money.zero);
      expect(lines.first.balance, Money.fromWire('10000.00'));
      expect(lines.last.balance, Money.fromWire('9000.00'));
    });

    test('the browsing list runs the other way, newest first', () async {
      final statement = statementOf(
        openingAsOf: Money.zero,
        bills: [bill('b1', '1000.00', augStart)],
        paid: [payment('p1', '500.00', augEnd)],
      );

      expect(statement.movements.first.dateMs, augEnd);
      expect(statement.lines.first.dateMs, augStart);
      // No running balance on the browsing list: it is scrolled, not
      // reconciled, and a partial running total would invite reading it as one.
      expect(statement.movements.first.balance, isNull);
    });
  });
}
