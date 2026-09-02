import 'package:get/get.dart';

import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // Eager, not lazyPut: the splash view never reads `controller`, so a lazy
    // registration would never be constructed and onReady() — which is what
    // navigates onward — would never run.
    Get.put<SplashController>(SplashController());
  }
}
