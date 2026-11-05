import 'package:get/get.dart';

import '../../accounts/controllers/accounts_controller.dart';
import '../../activity/controllers/activity_controller.dart';
import '../../customers/controllers/customers_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../more/controllers/more_controller.dart';
import '../../parties/controllers/parties_controller.dart';
import '../../purchases/controllers/purchases_controller.dart';
import '../../sales/controllers/sales_controller.dart';
import '../../suppliers/controllers/suppliers_controller.dart';
import '../controllers/home_controller.dart';

/// The shell holds every tab at once, so their controllers are registered
/// together as each is built.
///
/// `fenix` on the tab controllers because the [IndexedStack] keeps all five
/// alive but a deeper route can still dispose one on the way back; without it
/// the tab would return to a controller that no longer exists.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(HomeController.new);
    Get.lazyPut<DashboardController>(DashboardController.new, fenix: true);
    Get.lazyPut<ActivityController>(ActivityController.new, fenix: true);
    Get.lazyPut<PartiesController>(PartiesController.new, fenix: true);
    Get.lazyPut<CustomersController>(CustomersController.new, fenix: true);
    Get.lazyPut<SuppliersController>(SuppliersController.new, fenix: true);
    Get.lazyPut<AccountsController>(AccountsController.new, fenix: true);
    Get.lazyPut<MoreController>(MoreController.new, fenix: true);

    // Their lists are pushed from More now, but stay here so they survive the
    // trip and are not rebuilt from scratch each time.
    Get.lazyPut<PurchasesController>(PurchasesController.new, fenix: true);
    Get.lazyPut<SalesController>(SalesController.new, fenix: true);
  }
}
