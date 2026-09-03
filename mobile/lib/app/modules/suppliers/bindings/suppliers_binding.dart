import 'package:get/get.dart';

import '../controllers/supplier_detail_controller.dart';
import '../controllers/supplier_form_controller.dart';
import '../controllers/supplier_statement_controller.dart';

/// One binding per pushed supplier screen.
///
/// The list has none: it is a tab inside `HomeView`, so `HomeBinding` registers
/// `SuppliersController` and keeps it alive for as long as the shell is.
///
/// `lazyPut` without `fenix` on purpose here — a controller below holds its
/// screen's filters and its subscription to the change bus, and both should die
/// with the route. Reviving a disposed detail controller would resurrect a
/// subscription nothing is watching.
class SupplierFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SupplierFormController>(SupplierFormController.new);
  }
}

class SupplierDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SupplierDetailController>(SupplierDetailController.new);
  }
}

class SupplierStatementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SupplierStatementController>(SupplierStatementController.new);
  }
}
