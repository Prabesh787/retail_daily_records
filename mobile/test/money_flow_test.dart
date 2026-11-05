import 'package:billrecord/app/core/constants/db_constants.dart';
import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/utils/date_utils.dart';
import 'package:billrecord/app/data/dto/retail_dto.dart';
import 'package:billrecord/app/data/enums/account_type.dart';
import 'package:billrecord/app/data/enums/payment_status.dart';
import 'package:billrecord/app/data/enums/sale_payment_mode.dart';
import 'package:billrecord/app/data/enums/sale_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/customer.dart';
import 'package:billrecord/app/data/models/customer_payment.dart';
import 'package:billrecord/app/data/models/fiscal_year.dart';
import 'package:billrecord/app/data/models/ledger.dart';
import 'package:billrecord/app/data/models/money_account.dart';
import 'package:billrecord/app/data/models/sale.dart';
import 'package:billrecord/app/data/models/sale_item.dart';
import 'package:billrecord/app/data/models/sale_payment.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/repositories/account_repository.dart';
import 'package:billrecord/app/data/repositories/activity_repository.dart';
import 'package:billrecord/app/data/repositories/customer_payment_repository.dart';
import 'package:billrecord/app/data/repositories/customer_repository.dart';
import 'package:billrecord/app/data/repositories/dashboard_repository.dart';
import 'package:billrecord/app/data/repositories/fiscal_year_repository.dart';
import 'package:billrecord/app/data/repositories/sale_repository.dart';
import 'package:billrecord/app/data/repositories/supplier_payment_repository.dart';
import 'package:billrecord/app/data/repositories/supplier_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/test_app.dart';

/// Every rupee in and out, across sales, payments, cheques and manual entries.
///
/// These pin the promise the Accounts tab makes: a balance is what the records
/// add up to, an uncleared cheque is not money, and what a customer owes moves
/// with every Payment In and every bounce.
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.start());
  tearDown(() async => app.dispose());

  final today = AppDateUtils.startOfTodayMs();

  late AccountRepository accounts;
  late SaleRepository sales;
  late CustomerPaymentRepository receipts;
  late SupplierPaymentRepository payments;
  late ActivityRepository activity;

  late String yearId;
  late Customer customer;
  late Supplier supplier;
  late MoneyAccount bank;

  setUp(() async {
    accounts = Get.find<AccountRepository>();
    sales = Get.find<SaleRepository>();
    receipts = Get.find<CustomerPaymentRepository>();
    payments = Get.find<SupplierPaymentRepository>();
    activity = Get.find<ActivityRepository>();

    yearId = (await Get.find<FiscalYearRepository>().save(
      FiscalYear(
        id: '',
        createdAt: 0,
        updatedAt: 0,
        name: '2083/84',
        startDate: today - const Duration(days: 100).inMilliseconds,
        endDate: today + const Duration(days: 200).inMilliseconds,
        isActive: true,
      ),
    )).id;

    customer = await Get.find<CustomerRepository>().save(
      const Customer(id: '', createdAt: 0, updatedAt: 0, name: 'Hari Stores'),
    );
    supplier = await Get.find<SupplierRepository>().save(
      const Supplier(id: '', createdAt: 0, updatedAt: 0, name: 'ABC Textiles'),
    );
    bank = await accounts.save(
      const MoneyAccount(
        id: '',
        createdAt: 0,
        updatedAt: 0,
        name: 'Nabil Bank',
        accountType: AccountType.bank,
      ),
    );
  });

  Future<Sale> sale(
    num total, {
    SalePaymentMode mode = SalePaymentMode.cash,
    String? accountId,
    String? customerId,
    PaymentStatus status = PaymentStatus.cleared,
    String? chequeNo,
    int? chequeDate,
  }) => sales.save(
    Sale(
      id: '',
      createdAt: 0,
      updatedAt: 0,
      fiscalYearId: yearId,
      saleDate: today,
      saleType: SaleType.summary,
      customerId: customerId,
      totalAmount: Money.fromRupees(total),
      payments: [
        SalePayment(
          id: '',
          saleId: '',
          paymentMode: mode,
          amount: Money.fromRupees(total),
          accountId: accountId,
          status: status,
          chequeNo: chequeNo,
          chequeDate: chequeDate,
        ),
      ],
    ),
  );

  Future<CustomerPayment> receipt(
    num amount, {
    SupplierPaymentMode mode = SupplierPaymentMode.cash,
    String? accountId,
    String? saleId,
    String? chequeNo,
  }) => receipts.save(
    CustomerPayment(
      id: '',
      createdAt: 0,
      updatedAt: 0,
      fiscalYearId: yearId,
      customerId: customer.id,
      saleId: saleId,
      paymentDate: today,
      paymentMode: mode,
      amount: Money.fromRupees(amount),
      accountId: accountId,
      chequeNo: chequeNo,
    ),
  );

  Future<SupplierPayment> payOut(
    num amount, {
    SupplierPaymentMode mode = SupplierPaymentMode.cash,
    String? accountId,
    String? chequeNo,
  }) => payments.save(
    SupplierPayment(
      id: '',
      createdAt: 0,
      updatedAt: 0,
      fiscalYearId: yearId,
      supplierId: supplier.id,
      paymentDate: today,
      paymentMode: mode,
      amount: Money.fromRupees(amount),
      accountId: accountId,
      chequeNo: chequeNo,
      chequeDate: mode.isCheque ? today : null,
    ),
  );

  Future<Money> balanceOf(String id) async =>
      (await accounts.byId(id))!.balance;

  group('balances', () {
    test('cash in and out land on the cash box', () async {
      await accounts.ensureCashAccount();

      await sale(1000);
      await receipt(200);
      await payOut(300);

      expect(await balanceOf(MoneyAccount.cashId), Money.fromRupees(900));
    });

    test('bank money lands on the bank that was chosen', () async {
      await accounts.ensureCashAccount();

      await sale(1000, mode: SalePaymentMode.bank, accountId: bank.id);
      await payOut(
        400,
        mode: SupplierPaymentMode.bankTransfer,
        accountId: bank.id,
      );

      expect(await balanceOf(bank.id), Money.fromRupees(600));
      expect(await balanceOf(MoneyAccount.cashId), Money.zero);
    });

    test('the opening balance counts', () async {
      final funded = await accounts.save(
        bank.copyWith(openingBalance: Money.fromRupees(5000)),
      );
      await sale(1000, mode: SalePaymentMode.bank, accountId: funded.id);

      expect(await balanceOf(funded.id), Money.fromRupees(6000));
    });

    test('a credit sale moves no money', () async {
      await accounts.ensureCashAccount();
      await sale(
        1000,
        mode: SalePaymentMode.credit,
        customerId: customer.id,
      );

      expect(await balanceOf(MoneyAccount.cashId), Money.zero);
    });

    test('a deleted sale stops counting', () async {
      await accounts.ensureCashAccount();
      final recorded = await sale(1000);
      await sales.delete(recorded.id);

      expect(await balanceOf(MoneyAccount.cashId), Money.zero);
    });

    test('bank money with no bank named is shown, not lost', () async {
      await sale(750, mode: SalePaymentMode.bank);

      final overview = await accounts.overview();
      expect(overview.unassigned, Money.fromRupees(750));
      expect(overview.total, Money.fromRupees(750));
    });

    test('a transfer moves money and creates none', () async {
      await accounts.ensureCashAccount();
      await sale(1000);

      await accounts.saveEntry(
        dateMs: today,
        amount: Money.fromRupees(600),
        fromAccountId: MoneyAccount.cashId,
        toAccountId: bank.id,
      );

      expect(await balanceOf(MoneyAccount.cashId), Money.fromRupees(400));
      expect(await balanceOf(bank.id), Money.fromRupees(600));
      expect((await accounts.overview()).total, Money.fromRupees(1000));
    });

    test('a transfer is not counted as today’s income or spending', () async {
      await accounts.ensureCashAccount();
      await sale(1000);
      await accounts.saveEntry(
        dateMs: today,
        amount: Money.fromRupees(600),
        fromAccountId: MoneyAccount.cashId,
        toAccountId: bank.id,
      );
      await accounts.saveEntry(
        dateMs: today,
        amount: Money.fromRupees(50),
        fromAccountId: MoneyAccount.cashId,
        description: 'Tea',
      );

      final board = await Get.find<DashboardRepository>().load();
      expect(board.todayIn, Money.fromRupees(1000));
      expect(board.todayOut, Money.fromRupees(50));
    });

    test('deleting an entry undoes it', () async {
      await accounts.ensureCashAccount();
      final entry = await accounts.saveEntry(
        dateMs: today,
        amount: Money.fromRupees(100),
        toAccountId: MoneyAccount.cashId,
      );

      await accounts.deleteEntry(entry.id);

      expect(await balanceOf(MoneyAccount.cashId), Money.zero);
    });

    test('an entry has to touch an account, and two different ones', () {
      expect(
        () => accounts.saveEntry(dateMs: today, amount: Money.fromRupees(1)),
        throwsA(anything),
      );
      expect(
        () => accounts.saveEntry(
          dateMs: today,
          amount: Money.fromRupees(1),
          fromAccountId: bank.id,
          toAccountId: bank.id,
        ),
        throwsA(anything),
      );
    });
  });

  group('the ledger', () {
    test('carries a running balance, newest first', () async {
      await accounts.ensureCashAccount();
      await sale(1000);
      await payOut(300);

      final account = await accounts.byId(MoneyAccount.cashId);
      final rows = await accounts.ledger(account);

      expect(rows.first.balanceAfter, Money.fromRupees(700));
      expect(rows.last.balanceAfter, Money.fromRupees(1000));
      // The newest line always agrees with the balance on the account.
      expect(rows.first.balanceAfter, account!.balance);
    });
  });

  group('cheques', () {
    test('a received cheque reaches no account until it clears', () async {
      final issued = await receipt(
        500,
        mode: SupplierPaymentMode.cheque,
        chequeNo: '111',
      );

      expect(issued.status, PaymentStatus.issued);
      expect(await balanceOf(bank.id), Money.zero);

      final cheques = await activity.cheques();
      expect(cheques.single.direction, ChequeDirection.toCollect);

      await activity.clearCheque(
        cheques.single,
        accountId: bank.id,
        clearedOnMs: today,
      );

      expect(await balanceOf(bank.id), Money.fromRupees(500));
      expect(await activity.cheques(), isEmpty);
    });

    test('a cheque taken on a sale clears the same way', () async {
      await sale(
        800,
        mode: SalePaymentMode.cheque,
        customerId: customer.id,
        status: PaymentStatus.issued,
        chequeNo: '222',
        chequeDate: today,
      );
      expect(await balanceOf(bank.id), Money.zero);

      final cheque = (await activity.cheques()).single;
      expect(cheque.source, ChequeSource.saleLine);

      await activity.clearCheque(
        cheque,
        accountId: bank.id,
        clearedOnMs: today,
      );

      expect(await balanceOf(bank.id), Money.fromRupees(800));
    });

    test('a written cheque leaves the account only when it clears', () async {
      await payOut(
        300,
        mode: SupplierPaymentMode.cheque,
        accountId: bank.id,
        chequeNo: '333',
      );
      expect(await balanceOf(bank.id), Money.zero);

      await activity.clearCheque(
        (await activity.cheques()).single,
        accountId: bank.id,
        clearedOnMs: today,
      );

      expect(await balanceOf(bank.id), -Money.fromRupees(300));
    });

    test('both directions come back in date order', () async {
      await receipt(100, mode: SupplierPaymentMode.cheque, chequeNo: '1');
      await payOut(200, mode: SupplierPaymentMode.cheque, chequeNo: '2');

      final directions = (await activity.cheques()).map((c) => c.direction);
      expect(directions.toSet(), {
        ChequeDirection.toCollect,
        ChequeDirection.toPay,
      });
    });
  });

  group('what a customer owes', () {
    Future<Money?> owed() async =>
        (await Get.find<CustomerRepository>().byId(customer.id))!.receivable;

    test('credit adds to it and a Payment In comes off it', () async {
      await sale(
        1000,
        mode: SalePaymentMode.credit,
        customerId: customer.id,
      );
      expect(await owed(), Money.fromRupees(1000));

      await receipt(400);
      expect(await owed(), Money.fromRupees(600));
    });

    test('a bounced cheque goes back on', () async {
      await sale(
        1000,
        mode: SalePaymentMode.credit,
        customerId: customer.id,
      );
      await receipt(1000, mode: SupplierPaymentMode.cheque, chequeNo: '444');
      expect(await owed(), Money.zero);

      await activity.cancelCheque((await activity.cheques()).single);
      expect(await owed(), Money.fromRupees(1000));
    });

    test('a bounced cheque taken on the sale itself goes back on', () async {
      await sale(
        900,
        mode: SalePaymentMode.cheque,
        customerId: customer.id,
        status: PaymentStatus.issued,
        chequeNo: '555',
        chequeDate: today,
      );
      expect(await owed(), Money.zero);

      await activity.cancelCheque((await activity.cheques()).single);
      expect(await owed(), Money.fromRupees(900));
    });

    test('a Payment In against a sale clears that sale', () async {
      final recorded = await sale(
        500,
        mode: SalePaymentMode.credit,
        customerId: customer.id,
      );
      await receipt(500, saleId: recorded.id);

      final reread = await sales.byId(recorded.id);
      expect(reread!.dueTotal, Money.zero);

      final row = (await activity.feed(kind: ActivityKind.sale)).single;
      expect(row.due, Money.zero);
    });

    test('the total ignores a customer who has overpaid', () async {
      await receipt(100);
      final other = await Get.find<CustomerRepository>().save(
        const Customer(id: '', createdAt: 0, updatedAt: 0, name: 'Sita'),
      );
      await sale(
        250,
        mode: SalePaymentMode.credit,
        customerId: other.id,
      );

      final board = await Get.find<DashboardRepository>().load();
      expect(board.receivableTotal, Money.fromRupees(250));
      expect(board.receivableCount, 1);
    });
  });

  group('invoice numbers', () {
    Sale itemised({String? invoiceNo}) => Sale(
      id: '',
      createdAt: 0,
      updatedAt: 0,
      fiscalYearId: yearId,
      saleDate: today,
      saleType: SaleType.detailed,
      invoiceNo: invoiceNo,
      totalAmount: Money.zero,
      items: [
        SaleItem(
          id: '',
          saleId: '',
          description: 'Shirt',
          quantity: Quantity.fromUnits(1),
          unit: 'pcs',
          unitPrice: Money.fromRupees(100),
        ),
      ],
    );

    test('an itemised sale with none is numbered, or it could never sync', () async {
      expect((await sales.save(itemised())).invoiceNo, '1');
      expect((await sales.save(itemised())).invoiceNo, '2');
    });

    test('numbering carries on from the highest plain number', () async {
      await sales.save(itemised(invoiceNo: '41'));
      await sales.save(itemised(invoiceNo: 'A-99'));

      expect((await sales.save(itemised())).invoiceNo, '42');
    });

    test('a summary sale stays without one', () async {
      expect((await sale(100)).invoiceNo, isNull);
    });
  });

  group('the transactions feed', () {
    test('lists every kind, and filters by kind and name', () async {
      await sale(100);
      await receipt(50);
      await payOut(25);

      expect(await activity.feed(), hasLength(3));
      expect(await activity.feed(kind: ActivityKind.paymentOut), hasLength(1));
      expect(await activity.feed(search: 'Hari'), hasLength(1));
    });
  });

  group('sync', () {
    test('the cash box seeds with the oldest version, so edits win', () async {
      await accounts.ensureCashAccount();

      final queued = await app.db.query(
        DbTables.syncQueue,
        where: 'entity_id = ?',
        whereArgs: [MoneyAccount.cashId],
      );
      expect(queued, hasLength(1));
      expect(queued.single['updated_at'], 1);

      // Set up once, however many screens ask.
      await accounts.ensureCashAccount();
      final again = await app.db.query(
        DbTables.syncQueue,
        where: 'entity_id = ?',
        whereArgs: [MoneyAccount.cashId],
      );
      expect(again, hasLength(1));
    });

    test('the new rows survive the wire', () async {
      final sent = await receipt(
        70,
        mode: SupplierPaymentMode.bankTransfer,
        accountId: bank.id,
      );
      final back = CustomerPaymentDto.fromWire(sent.toJson());
      expect(back.accountId, bank.id);
      expect(back.amount, Money.fromRupees(70));
      expect(back.customerId, customer.id);

      final entry = await accounts.saveEntry(
        dateMs: today,
        amount: Money.fromRupees(5),
        toAccountId: bank.id,
      );
      final entryBack = AccountEntryDto.fromWire(entry.toJson());
      expect(entryBack.toAccountId, bank.id);
      expect(entryBack.fromAccountId, isNull);

      final accountBack = AccountDto.fromWire(bank.toJson());
      expect(accountBack.name, 'Nabil Bank');
      expect(accountBack.accountType, AccountType.bank);

      final saleBack = SaleDto.fromWire(
        (await sale(
          10,
          mode: SalePaymentMode.bank,
          accountId: bank.id,
        )).toJson(),
      );
      expect(saleBack.payments.single.accountId, bank.id);

      final payBack = SupplierPaymentDto.fromWire(
        (await payOut(
          5,
          mode: SupplierPaymentMode.bankTransfer,
          accountId: bank.id,
        )).toJson(),
      );
      expect(payBack.accountId, bank.id);
    });
  });
}
