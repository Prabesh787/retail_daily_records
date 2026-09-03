import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/data/enums/payment_status.dart';
import 'package:billrecord/app/data/enums/sale_payment_mode.dart';
import 'package:billrecord/app/data/enums/sale_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/sale.dart';
import 'package:billrecord/app/data/models/sale_payment.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/providers/local/sale_dao.dart';
import 'package:billrecord/app/data/repositories/sale_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The day book is where the product's sharpest rule has to hold: **credit is
/// not takings**. A sale made on account is turnover but not money, and a day
/// screen that adds the two together is how a shop's till stops matching its
/// own book.
///
/// These cover the arithmetic in [DayBook], which is the only place the day's
/// figures are produced — there is no stored day total anywhere in the system.
void main() {
  const int day = 1756771200000;

  SalePayment paid(
    SalePaymentMode mode,
    String amount, {
    PaymentStatus status = PaymentStatus.cleared,
  }) => SalePayment(
    id: 'p-$mode-$amount',
    saleId: 's',
    createdAt: 0,
    paymentMode: mode,
    amount: Money.fromWire(amount),
    status: status,
  );

  Sale sale(String total, {List<SalePayment> payments = const []}) => Sale(
    id: 's-$total',
    createdAt: 0,
    updatedAt: 0,
    fiscalYearId: 'fy',
    saleDate: day,
    saleType: SaleType.summary,
    totalAmount: Money.fromWire(total),
    payments: payments,
  );

  DayBook book({
    List<Sale> sales = const [],
    List<Purchase> purchases = const [],
    List<SupplierPayment> payments = const [],
  }) => DayBook(
    day: SalesDay(
      dateMs: day,
      total: Money.sum(sales.map((s) => s.totalAmount)),
      count: sales.length,
      sales: sales,
    ),
    purchases: purchases,
    payments: payments,
  );

  test('a cash sale is both sold and taken', () {
    final result = book(
      sales: [
        sale('1000.00', payments: [paid(SalePaymentMode.cash, '1000.00')]),
      ],
    );

    expect(result.salesTotal, Money.fromWire('1000.00'));
    expect(result.received, Money.fromWire('1000.00'));
    expect(result.onCredit, Money.zero);
  });

  test('a credit sale is sold but not taken', () {
    // The rule the whole screen exists for. Turnover moved; no money did.
    final result = book(
      sales: [
        sale('1000.00', payments: [paid(SalePaymentMode.credit, '1000.00')]),
      ],
    );

    expect(result.salesTotal, Money.fromWire('1000.00'));
    expect(result.received, Money.zero);
    expect(result.onCredit, Money.fromWire('1000.00'));
  });

  test('a part-paid sale splits between the two figures', () {
    final result = book(
      sales: [
        sale(
          '1000.00',
          payments: [
            paid(SalePaymentMode.cash, '400.00'),
            paid(SalePaymentMode.credit, '600.00'),
          ],
        ),
      ],
    );

    expect(result.received, Money.fromWire('400.00'));
    expect(result.onCredit, Money.fromWire('600.00'));
    // The two always reconstruct the total — that is what makes the card's
    // headline and its caption impossible to contradict.
    expect(result.received + result.onCredit, result.salesTotal);
  });

  test('a bounced cheque is not takings', () {
    final result = book(
      sales: [
        sale(
          '5000.00',
          payments: [
            paid(
              SalePaymentMode.cheque,
              '5000.00',
              status: PaymentStatus.cancelled,
            ),
          ],
        ),
      ],
    );

    expect(result.received, Money.zero);
    expect(result.onCredit, Money.fromWire('5000.00'));
  });

  test('the mode split excludes cancelled instruments', () {
    // Otherwise the split would total more than `received` claims, and the
    // card would disagree with itself.
    final result = book(
      sales: [
        sale(
          '3000.00',
          payments: [
            paid(SalePaymentMode.cash, '1000.00'),
            paid(
              SalePaymentMode.cheque,
              '2000.00',
              status: PaymentStatus.cancelled,
            ),
          ],
        ),
      ],
    );

    expect(result.byMode.length, 1);
    expect(result.byMode.single.mode, SalePaymentMode.cash);
    expect(
      Money.sum(result.byMode.map((r) => r.amount)),
      result.received,
    );
  });

  test('the mode split adds up across sales, largest first', () {
    final result = book(
      sales: [
        sale('100.00', payments: [paid(SalePaymentMode.cash, '100.00')]),
        sale('900.00', payments: [paid(SalePaymentMode.bank, '900.00')]),
        sale('200.00', payments: [paid(SalePaymentMode.cash, '200.00')]),
      ],
    );

    expect(result.byMode.first.mode, SalePaymentMode.bank);
    expect(result.byMode.first.amount, Money.fromWire('900.00'));
    expect(result.byMode.last.mode, SalePaymentMode.cash);
    // Two cash sales, summed rather than listed twice.
    expect(result.byMode.last.amount, Money.fromWire('300.00'));
  });

  test('one sale settled two ways appears under both modes', () {
    // Built from payment lines rather than sale headers precisely for this: a
    // header-level split would have to pick one mode and be wrong.
    final result = book(
      sales: [
        sale(
          '1000.00',
          payments: [
            paid(SalePaymentMode.cash, '600.00'),
            paid(SalePaymentMode.bank, '400.00'),
          ],
        ),
      ],
    );

    expect(result.byMode.length, 2);
    expect(result.received, Money.fromWire('1000.00'));
  });

  test('a day with no sales but money moving is not empty', () {
    final result = book(
      purchases: [
        Purchase(
          id: 'b1',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: 'fy',
          supplierId: 'sup',
          billNo: '1',
          billDate: day,
          amount: Money.fromWire('7000.00'),
        ),
      ],
    );

    expect(result.isEmpty, isFalse);
    expect(result.purchaseTotal, Money.fromWire('7000.00'));
    expect(result.received, Money.zero);
  });

  test('a cancelled supplier payment does not count as money paid out', () {
    final result = book(
      payments: [
        SupplierPayment(
          id: 'sp1',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: 'fy',
          supplierId: 'sup',
          paymentDate: day,
          paymentMode: SupplierPaymentMode.cash,
          amount: Money.fromWire('2000.00'),
          status: PaymentStatus.cancelled,
        ),
      ],
    );

    expect(result.paymentTotal, Money.zero);
    expect(result.isEmpty, isFalse);
  });

  test('a genuinely empty day is empty', () {
    expect(book().isEmpty, isTrue);
  });
}
