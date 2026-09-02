import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _boot();
  }

  /// Services are already initialised in main(), so this is only a brief brand
  /// moment before the first real screen.
  ///
  /// Signing in is required, so there are exactly two destinations: the books,
  /// or the front door.
  Future<void> _boot() async {
    final auth = AuthService.to;

    // Picks up a shop detail or a role changed elsewhere, and is where a token
    // revoked since last time is discovered - the 401 clears the session, so
    // the check below then correctly sends the user to login. Awaited rather
    // than fired and forgotten, because routing depends on the answer.
    if (auth.isSignedIn) await auth.refresh();

    await Future<void>.delayed(const Duration(milliseconds: 400));

    Get.offAllNamed(auth.isSignedIn ? Routes.home : Routes.login);
  }
}
