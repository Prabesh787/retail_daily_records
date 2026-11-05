import 'dart:io';

import 'package:billrecord/app/core/domain/money.dart';
import 'package:billrecord/app/core/theme/app_theme.dart';
import 'package:billrecord/app/core/utils/date_utils.dart';
import 'package:billrecord/app/data/enums/document_type.dart';
import 'package:billrecord/app/data/enums/sale_payment_mode.dart';
import 'package:billrecord/app/data/enums/sale_type.dart';
import 'package:billrecord/app/data/enums/supplier_payment_mode.dart';
import 'package:billrecord/app/data/models/fiscal_year.dart';
import 'package:billrecord/app/data/models/purchase.dart';
import 'package:billrecord/app/data/models/sale.dart';
import 'package:billrecord/app/data/models/sale_payment.dart';
import 'package:billrecord/app/data/models/supplier.dart';
import 'package:billrecord/app/data/models/supplier_payment.dart';
import 'package:billrecord/app/data/repositories/attachment_repository.dart';
import 'package:billrecord/app/data/repositories/fiscal_year_repository.dart';
import 'package:billrecord/app/data/repositories/purchase_repository.dart';
import 'package:billrecord/app/data/repositories/sale_repository.dart';
import 'package:billrecord/app/data/repositories/supplier_payment_repository.dart';
import 'package:billrecord/app/data/repositories/supplier_repository.dart';
import 'package:billrecord/app/modules/accounts/controllers/accounts_controller.dart';
import 'package:billrecord/app/modules/accounts/views/accounts_view.dart';
import 'package:billrecord/app/modules/activity/controllers/activity_controller.dart';
import 'package:billrecord/app/modules/activity/views/activity_view.dart';
import 'package:billrecord/app/modules/customers/bindings/customers_binding.dart';
import 'package:billrecord/app/modules/customers/controllers/customers_controller.dart';
import 'package:billrecord/app/core/widgets/domain/date_range_sheet.dart';
import 'package:billrecord/app/modules/gallery/bindings/gallery_binding.dart';
import 'package:billrecord/app/modules/gallery/controllers/gallery_controller.dart';
import 'package:billrecord/app/modules/gallery/views/gallery_view.dart';
import 'package:billrecord/app/modules/home/controllers/home_controller.dart';
import 'package:billrecord/app/modules/parties/controllers/parties_controller.dart';
import 'package:billrecord/app/modules/parties/views/parties_view.dart';
import 'package:billrecord/app/modules/sales/views/quick_sale_view.dart';
import 'package:billrecord/app/modules/dashboard/bindings/dashboard_binding.dart';
import 'package:billrecord/app/modules/dashboard/views/dashboard_view.dart';
import 'package:billrecord/app/modules/customers/views/customer_form_view.dart';
import 'package:billrecord/app/modules/customers/views/customers_view.dart';
import 'package:billrecord/app/modules/more/controllers/more_controller.dart';
import 'package:billrecord/app/modules/more/views/more_view.dart';
import 'package:billrecord/app/modules/payments/bindings/payments_binding.dart';
import 'package:billrecord/app/modules/payments/controllers/payment_form_controller.dart';
import 'package:billrecord/app/modules/payments/views/cheque_register_view.dart';
import 'package:billrecord/app/modules/payments/views/payment_detail_view.dart';
import 'package:billrecord/app/modules/payments/views/payment_form_view.dart';
import 'package:billrecord/app/modules/payments/views/receipt_form_view.dart';
import 'package:billrecord/app/modules/purchases/bindings/purchases_binding.dart';
import 'package:billrecord/app/modules/purchases/controllers/purchase_form_controller.dart';
import 'package:billrecord/app/modules/purchases/controllers/purchases_controller.dart';
import 'package:billrecord/app/modules/purchases/views/purchase_detail_view.dart';
import 'package:billrecord/app/modules/purchases/views/purchase_form_view.dart';
import 'package:billrecord/app/modules/purchases/views/purchases_view.dart';
import 'package:billrecord/app/modules/sales/bindings/sales_binding.dart';
import 'package:billrecord/app/modules/sales/controllers/sales_controller.dart';
import 'package:billrecord/app/modules/sales/views/sale_day_view.dart';
import 'package:billrecord/app/modules/sales/views/sale_detail_view.dart';
import 'package:billrecord/app/modules/sales/views/sale_form_view.dart';
import 'package:billrecord/app/modules/sales/views/sales_view.dart';
import 'package:billrecord/app/modules/settings/bindings/settings_binding.dart';
import 'package:billrecord/app/modules/settings/views/fiscal_years_view.dart';
import 'package:billrecord/app/modules/settings/views/shop_view.dart';
import 'package:billrecord/app/modules/suppliers/bindings/suppliers_binding.dart';
import 'package:billrecord/app/modules/suppliers/controllers/suppliers_controller.dart';
import 'package:billrecord/app/modules/suppliers/views/supplier_detail_view.dart';
import 'package:billrecord/app/modules/suppliers/views/supplier_form_view.dart';
import 'package:billrecord/app/modules/suppliers/views/supplier_statement_view.dart';
import 'package:billrecord/app/modules/suppliers/views/suppliers_view.dart';
import 'package:billrecord/app/routes/app_pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'helpers/test_app.dart';

/// Every screen, mounted for real.
///
/// These exist because of a bug no other test could have caught: a `bottomBar`
/// wrapped in an `Obx` whose closure only constructed a child read no
/// observables, and GetX threw the moment the sale form opened. Analyze was
/// clean, 165 unit tests passed, the APK built. Nothing had ever *run* a
/// screen.
///
/// So the bar here is deliberately low and deliberately broad: mount each
/// screen against a real database, with real repositories and real bindings,
/// and assert it renders without throwing. That is enough to catch misuse of
/// Obx, a missing binding, a null dereference on an empty list, and an
/// overflow — the failures that only appear when widgets actually build.
///
/// Each screen is mounted twice, empty and populated, because those are
/// different code paths and the empty one is the one nobody tries by hand.
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.start());
  tearDown(() async => app.dispose());

  final int today = AppDateUtils.startOfTodayMs();

  // ---- Seed data ----------------------------------------------------------

  Future<String> tempPhoto(String name) async {
    final dir = await Directory.systemTemp.createTemp('form_scan');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(List.filled(2048, 7));
    return file.path;
  }

  Future<FiscalYear> seedYear() => Get.find<FiscalYearRepository>().save(
    FiscalYear(
      id: '',
      createdAt: 0,
      updatedAt: 0,
      name: '2082/83',
      startDate: today - const Duration(days: 200).inMilliseconds,
      endDate: today + const Duration(days: 165).inMilliseconds,
      isActive: true,
    ),
  );

  Future<Supplier> seedSupplier() => Get.find<SupplierRepository>().save(
    Supplier(
      id: '',
      createdAt: 0,
      updatedAt: 0,
      name: 'ABC Textiles',
      phone: '9800000000',
      openingBalance: Money.fromWire('5000.00'),
    ),
  );

  Future<Purchase> seedBill(String yearId, String supplierId) =>
      Get.find<PurchaseRepository>().save(
        Purchase(
          id: '',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: yearId,
          supplierId: supplierId,
          billNo: '4471',
          billDate: today,
          amount: Money.fromWire('12000.00'),
          description: 'Cotton shirting',
        ),
      );

  Future<SupplierPayment> seedCheque(String yearId, String supplierId) =>
      Get.find<SupplierPaymentRepository>().save(
        SupplierPayment(
          id: '',
          createdAt: 0,
          updatedAt: 0,
          fiscalYearId: yearId,
          supplierId: supplierId,
          paymentDate: today,
          paymentMode: SupplierPaymentMode.cheque,
          amount: Money.fromWire('4000.00'),
          chequeNo: '00123',
          chequeDate: today + const Duration(days: 3).inMilliseconds,
        ),
      );

  Future<Sale> seedSale(String yearId) => Get.find<SaleRepository>().save(
    Sale(
      id: '',
      createdAt: 0,
      updatedAt: 0,
      fiscalYearId: yearId,
      invoiceNo: 'INV-1',
      saleDate: today,
      saleType: SaleType.summary,
      totalAmount: Money.fromWire('2500.00'),
      payments: [
        SalePayment(
          id: '',
          saleId: '',
          createdAt: 0,
          paymentMode: SalePaymentMode.cash,
          amount: Money.fromWire('2500.00'),
        ),
      ],
    ),
  );

  // ---- Suppliers ----------------------------------------------------------

  group('suppliers', () {
    testWidgets('list renders empty', (tester) async {
      await pumpScreen(
        tester,
        const SuppliersView(),
        binding: BindingsBuilder(() {
          Get.put(SuppliersController());
        }),
      );

      expect(find.text('No suppliers yet'), findsOneWidget);
    });

    testWidgets('list renders a supplier', (tester) async {
      await seed(tester, seedSupplier);
      await pumpScreen(
        tester,
        const SuppliersView(),
        binding: BindingsBuilder(() {
          Get.put(SuppliersController());
        }),
      );

      expect(find.text('ABC Textiles'), findsOneWidget);
    });

    testWidgets('form renders', (tester) async {
      await pumpScreen(
        tester,
        const SupplierFormView(),
        binding: SupplierFormBinding(),
      );

      expect(find.text('Add supplier'), findsOneWidget);
    });

    testWidgets('detail renders', (tester) async {
      final supplier = await seed(tester, seedSupplier);
      await pumpScreen(
        tester,
        const SupplierDetailView(),
        binding: SupplierDetailBinding(),
        arguments: {RouteArgs.supplierId: supplier.id},
      );

      expect(find.text('ABC Textiles'), findsWidgets);
    });

    testWidgets('statement renders', (tester) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      await seed(tester, () => seedBill(year.id, supplier.id));

      await pumpScreen(
        tester,
        const SupplierStatementView(),
        binding: SupplierStatementBinding(),
        arguments: {RouteArgs.supplierId: supplier.id},
      );

      expect(find.text('OPENING BALANCE'), findsOneWidget);
      expect(find.text('CLOSING BALANCE'), findsWidgets);
    });
  });

  // ---- Purchases ----------------------------------------------------------

  group('purchases', () {
    testWidgets('list renders empty', (tester) async {
      await pumpScreen(
        tester,
        const PurchasesView(),
        binding: BindingsBuilder(() {
          Get.put(PurchasesController());
        }),
      );

      expect(find.text('No purchases yet'), findsOneWidget);
    });

    testWidgets('list renders a bill', (tester) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      await seed(tester, () => seedBill(year.id, supplier.id));

      await pumpScreen(
        tester,
        const PurchasesView(),
        binding: BindingsBuilder(() {
          Get.put(PurchasesController());
        }),
      );

      expect(find.textContaining('4471'), findsWidgets);
    });

    testWidgets('form renders', (tester) async {
      await pumpScreen(
        tester,
        const PurchaseFormView(),
        binding: PurchaseFormBinding(),
      );

      expect(find.text('Save bill'), findsOneWidget);
      expect(find.text('Attach the paper bill'), findsOneWidget);
    });

    testWidgets('a photo taken on the form lands on the saved bill', (
      tester,
    ) async {
      await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      final photo = await seed(tester, () => tempPhoto('bill.jpg'));

      await pumpScreen(
        tester,
        const PurchaseFormView(),
        binding: PurchaseFormBinding(),
        arguments: {RouteArgs.presetSupplierId: supplier.id},
      );
      final form = Get.find<PurchaseFormController>();
      await settle(tester);

      form.scans.photos.add(XFile(photo));
      form.billNo.text = '4521';
      form.amount.text = '1200';
      await settle(tester);
      expect(find.byTooltip('Remove this photo'), findsOneWidget);

      await tester.tap(find.text('Save bill'));
      // Several real writes: the record, its queue row, then the photo copy.
      await settle(tester, rounds: 15);

      final bills = await seed(
        tester,
        () => Get.find<PurchaseRepository>().list(),
      );
      final filed = await seed(
        tester,
        () => Get.find<AttachmentRepository>().forEntity(
          AttachmentEntityType.purchase,
          bills.single.id,
        ),
      );
      expect(filed.single.documentType, DocumentType.purchaseBill);

      // Lets the confirmation toast finish, or its ticker outlives the test.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    });

    testWidgets('detail renders', (tester) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      final bill = await seed(tester, () => seedBill(year.id, supplier.id));

      await pumpScreen(
        tester,
        const PurchaseDetailView(),
        binding: PurchaseDetailBinding(),
        arguments: {RouteArgs.purchaseId: bill.id},
      );

      expect(find.text('BILL AMOUNT'), findsOneWidget);
    });
  });

  // ---- Payments -----------------------------------------------------------

  group('payments', () {
    testWidgets('form renders, and the cheque fields appear on demand', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const PaymentFormView(),
        binding: PaymentFormBinding(),
      );

      expect(find.text('Attach the receipt or cheque'), findsOneWidget);

      // Cash is the default, so the cheque fields must not be on screen yet.
      expect(find.text('Cheque number'), findsNothing);

      await tester.tap(find.text('Cheque'));
      await settle(tester);

      expect(find.text('Cheque number'), findsOneWidget);
      expect(find.text('Date on the cheque'), findsOneWidget);
    });

    testWidgets('detail renders a cheque', (tester) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      final cheque = await seed(tester, () => seedCheque(year.id, supplier.id));

      await pumpScreen(
        tester,
        const PaymentDetailView(),
        binding: PaymentDetailBinding(),
        arguments: {RouteArgs.paymentId: cheque.id},
      );

      expect(find.text('AMOUNT PAID'), findsOneWidget);
      expect(find.text('Attach the receipt or cheque'), findsOneWidget);
      // An issued cheque can still be cleared, so the action must be offered.
      expect(find.text('Mark as cleared'), findsOneWidget);
    });

    testWidgets('a photo taken on the form lands on the saved payment', (
      tester,
    ) async {
      await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      final photo = await seed(tester, () => tempPhoto('receipt.jpg'));

      await pumpScreen(
        tester,
        const PaymentFormView(),
        binding: PaymentFormBinding(),
        arguments: {RouteArgs.presetSupplierId: supplier.id},
      );
      final form = Get.find<PaymentFormController>();
      await settle(tester);

      form.scans.photos.add(XFile(photo));
      form.amount.text = '500';
      await settle(tester);
      expect(find.byTooltip('Remove this photo'), findsOneWidget);

      await tester.tap(find.text('Record payment'));
      // Several real writes: the record, its queue row, then the photo copy.
      await settle(tester, rounds: 15);

      final payments = await seed(
        tester,
        () => Get.find<SupplierPaymentRepository>().list(),
      );
      final filed = await seed(
        tester,
        () => Get.find<AttachmentRepository>().forEntity(
          AttachmentEntityType.supplierPayment,
          payments.single.id,
        ),
      );
      expect(filed.single.documentType, DocumentType.supplierPaymentReceipt);

      // Lets the confirmation toast finish, or its ticker outlives the test.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    });

    testWidgets('cheque register renders empty', (tester) async {
      await pumpScreen(
        tester,
        const ChequeRegisterView(),
        binding: ChequeRegisterBinding(),
      );

      expect(find.text('Nothing outstanding'), findsOneWidget);
    });

    testWidgets('Payment In form renders in its own right', (tester) async {
      await pumpScreen(
        tester,
        const ReceiptFormView(),
        binding: ReceiptFormBinding(),
      );

      expect(find.text('Payment In'), findsOneWidget);
      expect(find.text('Money coming in'), findsOneWidget);
    });

    testWidgets('cheque register buckets an issued cheque', (tester) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      await seed(tester, () => seedCheque(year.id, supplier.id));

      await pumpScreen(
        tester,
        const ChequeRegisterView(),
        binding: ChequeRegisterBinding(),
      );

      // Dated three days out, so it belongs to the week bucket and nowhere else.
      expect(find.text('NEXT 7 DAYS (1)'), findsOneWidget);
      expect(find.textContaining('OVERDUE'), findsNothing);
    });
  });

  // ---- Sales --------------------------------------------------------------

  group('sales', () {
    testWidgets('list renders empty', (tester) async {
      await pumpScreen(
        tester,
        const SalesView(),
        binding: BindingsBuilder(() {
          Get.put(SalesController());
        }),
      );

      expect(find.text('No sales yet'), findsOneWidget);
    });

    testWidgets('list renders a sale', (tester) async {
      final year = await seed(tester, seedYear);
      await seed(tester, () => seedSale(year.id));

      await pumpScreen(
        tester,
        const SalesView(),
        binding: BindingsBuilder(() {
          Get.put(SalesController());
        }),
      );

      expect(find.text('SOLD'), findsOneWidget);
      expect(find.text('TAKEN'), findsOneWidget);
    });

    /// The regression this whole file was written for: the save bar's `Obx`
    /// used to wrap a child that read its observables in its own build, and
    /// GetX threw the moment this screen opened.
    testWidgets('form renders, including its save bar', (tester) async {
      await pumpScreen(
        tester,
        const SaleFormView(),
        binding: SaleFormBinding(),
      );

      expect(find.text('Save sale'), findsOneWidget);
      expect(find.text('Total amount'), findsOneWidget);
      // A cash sale asks for nothing beyond the amount.
      expect(find.text('Customer (optional)'), findsOneWidget);
    });

    testWidgets('form switches to the itemised shape', (tester) async {
      await pumpScreen(
        tester,
        const SaleFormView(),
        binding: SaleFormBinding(),
      );

      await tester.tap(find.text('Add items'));
      await settle(tester);

      expect(find.text('Add line'), findsOneWidget);
      expect(find.text('Lines total'), findsOneWidget);
    });

    testWidgets('detail renders', (tester) async {
      final year = await seed(tester, seedYear);
      final sale = await seed(tester, () => seedSale(year.id));

      await pumpScreen(
        tester,
        const SaleDetailView(),
        binding: SaleDetailBinding(),
        arguments: {RouteArgs.saleId: sale.id},
      );

      expect(find.text('SALE TOTAL'), findsOneWidget);
    });

    testWidgets('day book renders an empty day', (tester) async {
      await pumpScreen(
        tester,
        const SaleDayView(),
        binding: SaleDayBinding(),
        arguments: {RouteArgs.dateMs: today},
      );

      expect(find.text('Nothing on this day'), findsOneWidget);
    });

    testWidgets('day book renders takings and the other side of the day', (
      tester,
    ) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      await seed(tester, () => seedSale(year.id));
      await seed(tester, () => seedBill(year.id, supplier.id));

      await pumpScreen(
        tester,
        const SaleDayView(),
        binding: SaleDayBinding(),
        arguments: {RouteArgs.dateMs: today},
      );

      expect(find.text('TAKINGS'), findsOneWidget);
      // The bill dated the same day is the half a sales-only screen would miss.
      expect(find.textContaining('BILLS TAKEN ON'), findsOneWidget);
    });
  });

  // ---- Dashboard ----------------------------------------------------------

  group('dashboard', () {
    testWidgets('welcomes a shop with nothing recorded', (tester) async {
      await pumpScreen(
        tester,
        const DashboardView(),
        binding: DashboardBinding(),
      );

      expect(find.text('To receive'), findsOneWidget);
      expect(find.text('Quick Sale'), findsWidgets);
      // A fresh shop is a different thing from a quiet day, and says so.
      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('summarises a shop that has traded', (tester) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      await seed(tester, () => seedSale(year.id));
      await seed(tester, () => seedBill(year.id, supplier.id));
      await seed(tester, () => seedCheque(year.id, supplier.id));

      await pumpScreen(
        tester,
        const DashboardView(),
        binding: DashboardBinding(),
      );

      expect(find.text('To pay'), findsOneWidget);
      expect(find.text('Cash in hand'), findsOneWidget);
      expect(find.text('RECENT'), findsOneWidget);
      // The cheque is dated three days out, so it is on this week's reminder.
      expect(find.text('1 cheque this week'), findsOneWidget);
      expect(find.text('Nothing recorded yet'), findsNothing);
    });
  });

  // ---- Customers and settings ---------------------------------------------

  group('customers', () {
    testWidgets('list renders empty', (tester) async {
      await pumpScreen(
        tester,
        const CustomersView(),
        binding: CustomersBinding(),
      );

      expect(find.text('No customers yet'), findsOneWidget);
    });

    testWidgets('form renders', (tester) async {
      await pumpScreen(
        tester,
        const CustomerFormView(),
        binding: CustomerFormBinding(),
      );

      expect(find.text('Add customer'), findsOneWidget);
    });
  });

  group('settings', () {
    /// The state that quietly breaks every form in the app: nothing saves while
    /// no year covers today, so this screen has to say so rather than let the
    /// user discover it one rejected bill at a time.
    testWidgets('fiscal years warns when no year covers today', (tester) async {
      await pumpScreen(
        tester,
        const FiscalYearsView(),
        binding: FiscalYearsBinding(),
      );

      expect(find.text('No fiscal years yet'), findsOneWidget);
    });

    testWidgets('fiscal years marks the active one', (tester) async {
      await seed(tester, seedYear);

      await pumpScreen(
        tester,
        const FiscalYearsView(),
        binding: FiscalYearsBinding(),
      );

      expect(find.text('2082/83'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      // The seeded year spans today, so the warning must not be showing.
      expect(find.text('No year covers today'), findsNothing);
    });

    testWidgets('shop details renders', (tester) async {
      await pumpScreen(tester, const ShopView(), binding: ShopBinding());

      expect(find.text('Shop name'), findsOneWidget);
      expect(find.text('Currency symbol'), findsOneWidget);
    });

    testWidgets('more renders its sections and the theme control', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const MoreView(),
        binding: BindingsBuilder(() {
          Get.put(MoreController());
        }),
      );

      expect(find.text('Cheques'), findsOneWidget);
      expect(find.text('Day book'), findsOneWidget);
      expect(find.text('Fiscal years'), findsOneWidget);
      expect(find.text('Shop details'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });

  // ---- Upgrade screens ----------------------------------------------------

  group('quick sale', () {
    testWidgets('keys an amount and records it as cash', (tester) async {
      await seed(tester, seedYear);

      await pumpScreen(
        tester,
        const QuickSaleView(),
        binding: QuickSaleBinding(),
      );

      for (final key in ['1', '2', '0', '0']) {
        await tester.tap(find.text(key));
        await settle(tester);
      }
      expect(find.text('Rs 1,200.00'), findsOneWidget);

      await tester.tap(find.text('Record sale'));
      await settle(tester);

      final sales = await seed(tester, () => Get.find<SaleRepository>().list());
      expect(sales, hasLength(1));
      expect(sales.first.totalAmount, Money.fromRupees(1200));
      // Ready for the next one.
      expect(find.text('Rs 0.00'), findsOneWidget);

      // Lets the confirmation toast finish, or its ticker outlives the test.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    });

    testWidgets('a credit sale asks for the customer first', (tester) async {
      await seed(tester, seedYear);

      await pumpScreen(
        tester,
        const QuickSaleView(),
        binding: QuickSaleBinding(),
      );

      await tester.tap(find.text('5'));
      await settle(tester);
      await tester.tap(find.text('Credit'));
      await settle(tester);
      await tester.tap(find.text('Record credit sale'));
      await settle(tester);

      expect(find.text('A credit sale needs a customer'), findsOneWidget);
      final sales = await seed(tester, () => Get.find<SaleRepository>().list());
      expect(sales, isEmpty);
    });
  });

  group('gallery', () {
    testWidgets('renders empty', (tester) async {
      await pumpScreen(
        tester,
        const GalleryView(),
        binding: GalleryBinding(),
      );

      expect(find.text('No photos of bills yet'), findsOneWidget);
    });

    testWidgets('separates bills from receipts, under the supplier', (
      tester,
    ) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      final bill = await seed(tester, () => seedBill(year.id, supplier.id));
      final cheque = await seed(tester, () => seedCheque(year.id, supplier.id));
      final billPhoto = await seed(tester, () => tempPhoto('bill.jpg'));
      final chequePhoto = await seed(tester, () => tempPhoto('cheque.jpg'));
      await seed(
        tester,
        () => Get.find<AttachmentRepository>().add(
          entityType: AttachmentEntityType.purchase,
          entityId: bill.id,
          documentType: DocumentType.purchaseBill,
          sourcePath: billPhoto,
        ),
      );
      await seed(
        tester,
        () => Get.find<AttachmentRepository>().add(
          entityType: AttachmentEntityType.supplierPayment,
          entityId: cheque.id,
          documentType: DocumentType.chequeCopy,
          sourcePath: chequePhoto,
        ),
      );

      await pumpScreen(
        tester,
        const GalleryView(),
        binding: GalleryBinding(),
      );

      expect(find.text(supplier.name), findsOneWidget);
      expect(find.text('Bill 4471'), findsOneWidget);
      expect(find.textContaining('Cheque copy'), findsNothing);

      await tester.tap(find.text('Receipts'));
      await settle(tester);

      expect(find.textContaining('Cheque copy'), findsOneWidget);
      expect(find.text('Bill 4471'), findsNothing);
    });

    testWidgets('a filter that matches nothing can be cleared', (tester) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      final bill = await seed(tester, () => seedBill(year.id, supplier.id));
      final photo = await seed(tester, () => tempPhoto('bill.jpg'));
      await seed(
        tester,
        () => Get.find<AttachmentRepository>().add(
          entityType: AttachmentEntityType.purchase,
          entityId: bill.id,
          documentType: DocumentType.purchaseBill,
          sourcePath: photo,
        ),
      );

      await pumpScreen(
        tester,
        const GalleryView(),
        binding: GalleryBinding(),
      );
      expect(find.text('Clear'), findsNothing);

      final gallery = Get.find<GalleryController>();
      gallery.setRange(const DateRange(from: 0, to: 1));
      await settle(tester);
      expect(find.text('No bills match'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await settle(tester);
      expect(find.text('Bill 4471'), findsOneWidget);
    });
  });

  group('new tabs', () {
    BindingsBuilder<void> tabs() => BindingsBuilder(() {
      Get.put(HomeController());
      Get.put(ActivityController());
      Get.put(AccountsController());
      Get.put(PartiesController());
      Get.put(CustomersController());
    });

    testWidgets('transactions lists every kind together', (tester) async {
      final year = await seed(tester, seedYear);
      final supplier = await seed(tester, seedSupplier);
      await seed(tester, () => seedSale(year.id));
      await seed(tester, () => seedBill(year.id, supplier.id));
      await seed(tester, () => seedCheque(year.id, supplier.id));

      await pumpScreen(tester, const ActivityView(), binding: tabs());

      expect(find.text('ABC Textiles'), findsNWidgets(2));
      expect(find.text('Cheque pending'), findsOneWidget);
    });

    testWidgets('transactions renders empty', (tester) async {
      await pumpScreen(tester, const ActivityView(), binding: tabs());

      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('accounts sets up the cash box on first open', (tester) async {
      await pumpScreen(tester, const AccountsView(), binding: tabs());

      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
    });

    testWidgets('parties switches between its two halves', (tester) async {
      await pumpScreen(
        tester,
        const PartiesView(),
        binding: BindingsBuilder(() {
          Get.put(PartiesController());
          Get.put(CustomersController());
          Get.put(SuppliersController());
        }),
      );

      expect(find.text('No customers yet'), findsOneWidget);

      await tester.tap(find.text('Suppliers').first);
      await settle(tester);

      expect(Get.find<PartiesController>().tab.value, PartyTab.suppliers);
    });
  });

  // ---- Dark mode ----------------------------------------------------------

  /// The palette is a theme extension, and a widget that reaches for a
  /// hard-coded colour instead is invisible in one brightness while passing
  /// every test that only ever runs in light.
  testWidgets('the busiest screens build in dark too', (tester) async {
    final year = await seed(tester, seedYear);
    final supplier = await seed(tester, seedSupplier);
    await seed(tester, () => seedBill(year.id, supplier.id));
    await seed(tester, () => seedCheque(year.id, supplier.id));

    await pumpScreen(
      tester,
      const SupplierDetailView(),
      binding: SupplierDetailBinding(),
      arguments: {RouteArgs.supplierId: supplier.id},
      theme: AppTheme.dark,
    );

    expect(find.text('ABC Textiles'), findsWidgets);
  });
}
