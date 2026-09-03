import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/utils/date_utils.dart';
import 'package:billrecord/app/data/enums/sale_payment_mode.dart';
import 'package:billrecord/app/data/enums/sale_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/fiscal_year.dart';
import 'package:billrecord/app/data/models/sale.dart';
import 'package:billrecord/app/data/models/sale_payment.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/repositories/dashboard_repository.dart';
import 'package:billrecord/app/data/repositories/fiscal_year_repository.dart';
import 'package:billrecord/app/data/repositories/sale_repository.dart';
import 'package:billrecord/app/data/repositories/supplier_payment_repository.dart';
import 'package:billrecord/app/data/repositories/supplier_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/test_app.dart';

/// The dashboard summarises every other screen, so the thing worth testing is
/// that its summaries agree with the screens behind them. A figure nobody can
/// check by tapping through is a figure nobody ends up trusting.
///
/// Run against the real database through the real repositories — the same
/// composition the screen uses, not a rehearsal of it.
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.start();
    Get.put(DashboardRepository(), permanent: true);
  });
  tearDown(() async => app.dispose());

  final int today = AppDateUtils.startOfTodayMs();

  Future<FiscalYear> seedYear() => Get.find<FiscalYearRepository>().save(
    FiscalYear(
      id: '',
      createdAt: 0,
      updatedAt: 0,
      name: '2082/83',
      startDate: today - const Duration(days: 300).inMilliseconds,
      endDate: today + const Duration(days: 65).inMilliseconds,
      isActive: true,
    ),
  );

  Future<Sale> seedSale(
    String yearId, {
    required String total,
    int? dateMs,
    SalePaymentMode mode = SalePaymentMode.cash,
  }) =>
      Get.find<SaleRepository>().save(
        Sale(
          id: '',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: yearId,
          saleDate: dateMs ?? today,
          saleType: SaleType.summary,
          totalAmount: Money.fromWire(total),
          payments: [
            SalePayment(
              id: '',
              saleId: '',
              createdAt: 0,
              paymentMode: mode,
              amount: Money.fromWire(total),
            ),
          ],
        ),
      );

  Future<DashboardData> load() => Get.find<DashboardRepository>().load();

  test('a fresh shop reports zeros and says so', () async {
    final board = await load();

    expect(board.todaySales, Money.zero);
    expect(board.payableTotal, Money.zero);
    expect(board.unclearedTotal, Money.zero);
    expect(board.nextCheque, isNull);
    // Distinct from a quiet day, and the screen says something different.
    expect(board.isFresh, isTrue);
  });

  test('today\'s sales are today\'s, not the whole history', () async {
    final year = await seedYear();
    await seedSale(year.id, total: '1000.00');
    await seedSale(
      year.id,
      total: '9999.00',
      dateMs: today - const Duration(days: 3).inMilliseconds,
    );

    final board = await load();

    expect(board.todaySales, Money.fromWire('1000.00'));
    expect(board.todayCount, 1);
    // The older sale still exists — it is simply not today's.
    expect(board.latestSales.length, 2);
    expect(board.isFresh, isFalse);
  });

  test('a credit sale is sold today but not taken today', () async {
    final year = await seedYear();
    await seedSale(year.id, total: '2000.00', mode: SalePaymentMode.credit);

    final board = await load();

    // The same rule as the day book: turnover moved, money did not.
    expect(board.todaySales, Money.fromWire('2000.00'));
    expect(board.todayReceived, Money.zero);
    expect(board.todayOnCredit, Money.fromWire('2000.00'));
  });

  test('the trend has one point per day, including the quiet ones', () async {
    final year = await seedYear();
    await seedSale(year.id, total: '500.00');
    await seedSale(
      year.id,
      total: '700.00',
      dateMs: today - const Duration(days: 5).inMilliseconds,
    );

    final board = await load();

    // Fourteen days means thirteen back plus today. Dropping the empty days
    // would draw a line that skips them and make a bad week look steady.
    expect(board.trend.length, 14);
    expect(board.trend.last.dateMs, today);
    expect(board.trend.last.amount, Money.fromWire('500.00'));

    final quiet = board.trend.where((p) => p.amount.isZero);
    expect(quiet.length, 12);
  });

  test('the trend is in date order, oldest first', () async {
    final board = await load();

    for (var i = 1; i < board.trend.length; i++) {
      expect(
        board.trend[i].dateMs > board.trend[i - 1].dateMs,
        isTrue,
        reason: 'point $i is not after the one before it',
      );
    }
  });

  test('payable agrees with the supplier list behind it', () async {
    await Get.find<SupplierRepository>().save(
      Supplier(
        id: '',
        createdAt: 0,
        updatedAt: 0,
        name: 'ABC Textiles',
        openingBalance: Money.fromWire('5000.00'),
      ),
    );
    await Get.find<SupplierRepository>().save(
      Supplier(
        id: '',
        createdAt: 0,
        updatedAt: 0,
        name: 'XYZ Traders',
        openingBalance: Money.fromWire('3000.00'),
      ),
    );

    final board = await load();

    expect(board.payableTotal, Money.fromWire('8000.00'));
    expect(board.payableSupplierCount, 2);

    // The card's figure and the rows it links to are the same arithmetic.
    final listed = Money.sum(
      board.topOwed.map((s) => s.balance?.outstanding ?? Money.zero),
    );
    expect(listed, board.payableTotal);
    // Largest first, so "owed the most" means what it says.
    expect(board.topOwed.first.name, 'ABC Textiles');
  });

  /// A regression these tests found the hard way.
  ///
  /// `SaleRepository.save` re-keyed each line and payment to the sale but never
  /// gave them an id of their own, and a form has no business inventing primary
  /// keys — so every row arrived with `id: ''`. That inserts once and then
  /// violates the unique constraint, meaning the app would have saved exactly
  /// one sale with a payment and failed on the second, a long way from where
  /// the mistake was made.
  test('every sale gets its own payment ids', () async {
    final year = await seedYear();

    final first = await seedSale(year.id, total: '1000.00');
    // The one that used to throw.
    final second = await seedSale(year.id, total: '2000.00');

    expect(first.payments.single.id, isNotEmpty);
    expect(second.payments.single.id, isNotEmpty);
    expect(first.payments.single.id, isNot(second.payments.single.id));

    // And they survive the round trip, which is what the screens read back.
    final reread = await Get.find<SaleRepository>().byId(second.id);
    expect(reread?.payments.single.amount, Money.fromWire('2000.00'));
  });

  test('an issued cheque is both uncleared and the next one due', () async {
    final year = await seedYear();
    final supplier = await Get.find<SupplierRepository>().save(
      Supplier(id: '', createdAt: 0, updatedAt: 0, name: 'ABC Textiles'),
    );

    await Get.find<SupplierPaymentRepository>().save(
      SupplierPayment(
        id: '',
        createdAt: 0,
        updatedAt: 0,
        fiscalYearId: year.id,
        supplierId: supplier.id,
        paymentDate: today,
        paymentMode: SupplierPaymentMode.cheque,
        amount: Money.fromWire('4000.00'),
        chequeNo: '00123',
        chequeDate: today + const Duration(days: 4).inMilliseconds,
      ),
    );

    final board = await load();

    expect(board.unclearedTotal, Money.fromWire('4000.00'));
    expect(board.unclearedCount, 1);
    expect(board.nextCheque?.chequeNo, '00123');
  });

  test('the soonest cheque is the one surfaced', () async {
    final year = await seedYear();
    final supplier = await Get.find<SupplierRepository>().save(
      Supplier(id: '', createdAt: 0, updatedAt: 0, name: 'ABC Textiles'),
    );

    Future<void> cheque(String no, int days) =>
        Get.find<SupplierPaymentRepository>().save(
          SupplierPayment(
            id: '',
            createdAt: 0,
            updatedAt: 0,
            fiscalYearId: year.id,
            supplierId: supplier.id,
            paymentDate: today,
            paymentMode: SupplierPaymentMode.cheque,
            amount: Money.fromWire('1000.00'),
            chequeNo: no,
            chequeDate: today + Duration(days: days).inMilliseconds,
          ),
        );

    await cheque('LATER', 20);
    await cheque('SOONER', 2);

    final board = await load();

    // Ordered by the date on the cheque, not the day it was written — which is
    // the whole point of the register this figure comes from.
    expect(board.nextCheque?.chequeNo, 'SOONER');
  });
}

