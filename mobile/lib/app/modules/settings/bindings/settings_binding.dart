import 'package:get/get.dart';

import '../controllers/fiscal_years_controller.dart';
import '../controllers/shop_controller.dart';

class FiscalYearsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FiscalYearsController>(FiscalYearsController.new);
  }
}

class ShopBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShopController>(ShopController.new);
  }
}
