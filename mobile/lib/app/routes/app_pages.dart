import 'package:get/get.dart';

import '../modules/accounts/bindings/accounts_binding.dart';
import '../modules/accounts/views/account_detail_view.dart';
import '../modules/accounts/views/account_entry_view.dart';
import '../modules/accounts/views/account_form_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/customers/bindings/customers_binding.dart';
import '../modules/customers/views/customer_form_view.dart';
import '../modules/customers/views/customers_view.dart';
import '../modules/gallery/bindings/gallery_binding.dart';
import '../modules/gallery/views/gallery_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/payments/bindings/payments_binding.dart';
import '../modules/payments/views/cheque_register_view.dart';
import '../modules/payments/views/payment_detail_view.dart';
import '../modules/payments/views/payment_form_view.dart';
import '../modules/payments/views/receipt_detail_view.dart';
import '../modules/payments/views/receipt_form_view.dart';
import '../modules/purchases/bindings/purchases_binding.dart';
import '../modules/purchases/views/purchase_detail_view.dart';
import '../modules/purchases/views/purchase_form_view.dart';
import '../modules/purchases/views/purchases_view.dart';
import '../modules/sales/bindings/sales_binding.dart';
import '../modules/sales/views/sale_day_view.dart';
import '../modules/sales/views/sale_detail_view.dart';
import '../modules/sales/views/quick_sale_view.dart';
import '../modules/sales/views/sale_form_view.dart';
import '../modules/sales/views/sales_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/settings/views/fiscal_years_view.dart';
import '../modules/settings/views/shop_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/suppliers/bindings/suppliers_binding.dart';
import '../modules/suppliers/views/supplier_detail_view.dart';
import '../modules/suppliers/views/supplier_form_view.dart';
import '../modules/suppliers/views/supplier_statement_view.dart';
import 'auth_guard.dart';

part 'app_routes.dart';

/// Every route, its page and its binding.
///
/// The addresses mirror the web app's route table, so a screen is at the same
/// path in both.
///
/// Everything except the splash and login carries [AuthGuard]. The app serves
/// several shops off one backend and every record belongs to one of them, so
/// there is no screen worth showing without knowing whose books are open.
class AppPages {
  AppPages._();

  static const String initial = Routes.splash;

  /// Applied to every screen behind the login.
  static final List<GetMiddleware> _protected = [AuthGuard()];

  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
      middlewares: [GuestOnly()],
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      middlewares: _protected,
    ),

    // Suppliers. The list itself is a tab inside [HomeView] rather than a page
    // here — it keeps its search and scroll position while the user goes
    // elsewhere and comes back, which a pushed route would throw away. Only the
    // screens you actually navigate *to* are registered.
    GetPage(
      name: Routes.supplierForm,
      page: () => const SupplierFormView(),
      binding: SupplierFormBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.supplierDetail,
      page: () => const SupplierDetailView(),
      binding: SupplierDetailBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.supplierStatement,
      page: () => const SupplierStatementView(),
      binding: SupplierStatementBinding(),
      middlewares: _protected,
    ),

    // Purchases. Same shape as suppliers: the list is a shell tab, only the
    // screens you navigate to are registered here.
    GetPage(
      name: Routes.purchaseForm,
      page: () => const PurchaseFormView(),
      binding: PurchaseFormBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.gallery,
      page: () => const GalleryView(),
      binding: GalleryBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.purchaseDetail,
      page: () => const PurchaseDetailView(),
      binding: PurchaseDetailBinding(),
      middlewares: _protected,
    ),

    // Payments. All pushed — payments have no tab of their own, being reached
    // from a supplier, a bill, or the cheque register.
    GetPage(
      name: Routes.paymentForm,
      page: () => const PaymentFormView(),
      binding: PaymentFormBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.paymentDetail,
      page: () => const PaymentDetailView(),
      binding: PaymentDetailBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.cheques,
      page: () => const ChequeRegisterView(),
      binding: ChequeRegisterBinding(),
      middlewares: _protected,
    ),

    // Sales. The day book is reachable without arguments — it defaults to
    // today, which makes `/sales/day` a usable deep link on its own.
    GetPage(
      name: Routes.saleForm,
      page: () => const SaleFormView(),
      binding: SaleFormBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.saleDetail,
      page: () => const SaleDetailView(),
      binding: SaleDetailBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.saleDay,
      page: () => const SaleDayView(),
      binding: SaleDayBinding(),
      middlewares: _protected,
    ),

    GetPage(
      name: Routes.quickSale,
      page: () => const QuickSaleView(),
      binding: QuickSaleBinding(),
      middlewares: _protected,
    ),
    // The two document lists, reached from More. Their controllers belong to
    // `HomeBinding`, which is always alive underneath a pushed route.
    GetPage(
      name: Routes.sales,
      page: () => const SalesView(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.purchases,
      page: () => const PurchasesView(),
      middlewares: _protected,
    ),

    // Payment In: the mirror of the payment screens above.
    GetPage(
      name: Routes.receiptForm,
      page: () => const ReceiptFormView(),
      binding: ReceiptFormBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.receiptDetail,
      page: () => const ReceiptDetailView(),
      binding: ReceiptDetailBinding(),
      middlewares: _protected,
    ),

    // Accounts. The list is a shell tab; these are what it opens.
    GetPage(
      name: Routes.accountForm,
      page: () => const AccountFormView(),
      binding: AccountFormBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.accountDetail,
      page: () => const AccountDetailView(),
      binding: AccountDetailBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.accountEntry,
      page: () => const AccountEntryView(),
      binding: AccountEntryBinding(),
      middlewares: _protected,
    ),

    // Customers and settings. All reached from the More tab — a shop selling
    // over a counter for cash never needs any of them.
    GetPage(
      name: Routes.customers,
      page: () => const CustomersView(),
      binding: CustomersBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.customerForm,
      page: () => const CustomerFormView(),
      binding: CustomerFormBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.fiscalYears,
      page: () => const FiscalYearsView(),
      binding: FiscalYearsBinding(),
      middlewares: _protected,
    ),
    GetPage(
      name: Routes.shop,
      page: () => const ShopView(),
      binding: ShopBinding(),
      middlewares: _protected,
    ),
  ];
}
