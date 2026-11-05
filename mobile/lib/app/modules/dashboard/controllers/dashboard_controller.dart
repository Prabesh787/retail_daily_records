import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../data/models/ledger.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';
import '../../activity/controllers/activity_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../parties/controllers/parties_controller.dart';

/// The home screen.
///
/// Watches everything, because it summarises everything: a bill saved on
/// another tab, a cheque cleared two screens deep, or a row pulled down by sync
/// all change what this screen is claiming. It is the one place in the app
/// where watching every entity is the correct answer rather than a lazy one.
class DashboardController extends LoaderController<DashboardData> {
  final DashboardRepository _dashboard = Get.find<DashboardRepository>();

  @override
  List<String> get watches => const [
    DbTables.sale,
    DbTables.purchase,
    DbTables.supplier,
    DbTables.supplierPayment,
    DbTables.customerPayment,
    DbTables.customer,
    DbTables.account,
    DbTables.accountEntry,
  ];

  DashboardData? get board => data.value;

  @override
  Future<DashboardData> fetch() => _dashboard.load();

  String get shopName => AuthService.to.shopName;

  // Tapping a figure goes to the screen that shows the rows behind it. That is
  // the point of the dashboard: every number on it is checkable.
  void openTransactions() => _switchTab(HomeController.transactionsTab);
  void openAccounts() => _switchTab(HomeController.accountsTab);

  void openCustomers() => _openParties(PartyTab.customers);
  void openSuppliers() => _openParties(PartyTab.suppliers);

  void _openParties(PartyTab tab) {
    if (Get.isRegistered<PartiesController>()) {
      Get.find<PartiesController>().setTab(tab);
    }
    _switchTab(HomeController.partiesTab);
  }

  void openToday() => Get.toNamed<void>(Routes.saleDay);
  void openCheques() => Get.toNamed<void>(Routes.cheques);

  void open(ActivityItem item) {
    if (Get.isRegistered<ActivityController>()) {
      Get.find<ActivityController>().open(item);
    }
  }

  void newQuickSale() => Get.toNamed<void>(Routes.quickSale);
  void newSale() => Get.toNamed<void>(Routes.saleForm);
  void newPurchase() => Get.toNamed<void>(Routes.purchaseForm);
  void newPaymentIn() => Get.toNamed<void>(Routes.receiptForm);
  void newPaymentOut() => Get.toNamed<void>(Routes.paymentForm);
  void newCustomer() => Get.toNamed<void>(Routes.customerForm);
  void newSupplier() => Get.toNamed<void>(Routes.supplierForm);

  /// The lists live in the shell's tabs, so "see all" switches tab rather than
  /// pushing a second copy of a screen the user can already reach with a thumb.
  void _switchTab(int index) {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().changeTab(index);
    }
  }
}
