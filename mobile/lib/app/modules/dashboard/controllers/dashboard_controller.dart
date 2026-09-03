import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';
import '../../home/controllers/home_controller.dart';

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
  ];

  DashboardData? get board => data.value;

  @override
  Future<DashboardData> fetch() => _dashboard.load();

  /// "Good morning" and the like. Small thing, and the reason it is here rather
  /// than in the view is that a widget rebuilding at 11:59 should not change
  /// its greeting mid-scroll.
  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get shopName => AuthService.to.shopName;

  // Tapping a figure goes to the screen that shows the rows behind it. That is
  // the point of the dashboard: every number on it is checkable.
  void openSales() => _switchTab(2);
  void openSuppliers() => _switchTab(3);
  void openPurchases() => _switchTab(1);

  void openToday() => Get.toNamed<void>(Routes.saleDay);
  void openCheques() => Get.toNamed<void>(Routes.cheques);

  void openSupplier(String id) => Get.toNamed<void>(
    Routes.supplierDetail,
    arguments: {RouteArgs.supplierId: id},
  );

  void openSale(String id) => Get.toNamed<void>(
    Routes.saleDetail,
    arguments: {RouteArgs.saleId: id},
  );

  void openBill(String id) => Get.toNamed<void>(
    Routes.purchaseDetail,
    arguments: {RouteArgs.purchaseId: id},
  );

  void newSale() => Get.toNamed<void>(Routes.saleForm);
  void newPurchase() => Get.toNamed<void>(Routes.purchaseForm);
  void newPayment() => Get.toNamed<void>(Routes.paymentForm);

  /// The lists live in the shell's tabs, so "see all" switches tab rather than
  /// pushing a second copy of a screen the user can already reach with a thumb.
  void _switchTab(int index) {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().changeTab(index);
    }
  }
}
