import 'package:get/get.dart';

import '../controllers/purchase_detail_controller.dart';
import '../controllers/purchase_form_controller.dart';

/// One binding per pushed purchase screen.
///
/// The list has none: it is a tab inside `HomeView`, so `HomeBinding` owns
/// `PurchasesController` for as long as the shell lives.
class PurchaseFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PurchaseFormController>(PurchaseFormController.new);
  }
}

class PurchaseDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PurchaseDetailController>(PurchaseDetailController.new);
  }
}
