import 'package:get/get.dart';

import '../controllers/home_controller.dart';

/// The shell holds every tab at once, so their controllers are registered
/// together as each is built. `fenix` lets any of them be recreated if a deeper
/// route disposes it on the way back.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(HomeController.new);
  }
}
