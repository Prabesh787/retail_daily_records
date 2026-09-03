import 'package:get/get.dart';

import '../controllers/customer_form_controller.dart';
import '../controllers/customers_controller.dart';

class CustomersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomersController>(CustomersController.new);
  }
}

class CustomerFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerFormController>(CustomerFormController.new);
  }
}
