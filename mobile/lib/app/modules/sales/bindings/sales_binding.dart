import 'package:get/get.dart';

import '../controllers/sale_day_controller.dart';
import '../controllers/sale_detail_controller.dart';
import '../controllers/sale_form_controller.dart';

/// One binding per pushed sale screen. The list is a shell tab, so `HomeBinding`
/// owns `SalesController`.
class SaleFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SaleFormController>(SaleFormController.new);
  }
}

class SaleDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SaleDetailController>(SaleDetailController.new);
  }
}

class SaleDayBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SaleDayController>(SaleDayController.new);
  }
}
