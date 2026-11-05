import 'package:get/get.dart';

import '../controllers/account_detail_controller.dart';
import '../controllers/account_entry_controller.dart';
import '../controllers/account_form_controller.dart';

/// One binding per pushed account screen. The list is a shell tab, so
/// `HomeBinding` owns `AccountsController`.
class AccountFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountFormController>(AccountFormController.new);
  }
}

class AccountDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountDetailController>(AccountDetailController.new);
  }
}

class AccountEntryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountEntryController>(AccountEntryController.new);
  }
}
