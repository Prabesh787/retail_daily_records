import 'package:get/get.dart';

import '../../more/controllers/more_controller.dart';
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
    Get.lazyPut<SuppliersController>(SuppliersController.new, fenix: true);
    Get.lazyPut<PurchasesController>(PurchasesController.new, fenix: true);
    Get.lazyPut<SalesController>(SalesController.new, fenix: true);
    Get.lazyPut<MoreController>(MoreController.new, fenix: true);
  }
}
