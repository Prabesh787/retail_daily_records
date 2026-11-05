import 'package:get/get.dart';

import '../controllers/cheque_register_controller.dart';
import '../controllers/payment_detail_controller.dart';
import '../controllers/payment_form_controller.dart';
import '../controllers/receipt_detail_controller.dart';
import '../controllers/receipt_form_controller.dart';

/// One binding per payment screen. All three are pushed routes — payments have
/// no tab of their own, being reached from a supplier, a bill, or the register.
class PaymentFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentFormController>(PaymentFormController.new);
  }
}

class PaymentDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentDetailController>(PaymentDetailController.new);
  }
}

class ReceiptFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReceiptFormController>(ReceiptFormController.new);
  }
}

class ReceiptDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReceiptDetailController>(ReceiptDetailController.new);
  }
}

class ChequeRegisterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChequeRegisterController>(ChequeRegisterController.new);
  }
}
