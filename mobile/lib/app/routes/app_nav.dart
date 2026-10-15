import 'package:get/get.dart';

/// Leaving the current screen or dialog.
///
/// Use this instead of `Get.back`. In GetX 4, `Get.back` closes an open
/// snackbar *instead of* popping the route — so the usual "toast, then leave"
/// at the end of a save only dismissed the toast it had just shown, and the
/// form stayed on screen. Popping the navigator directly leaves the toast up
/// over the screen underneath, which is where the user wants to read it.
class AppNav {
  AppNav._();

  static void back<T>([T? result]) {
    final navigator = Get.key.currentState;
    if (navigator != null && navigator.canPop()) navigator.pop<T>(result);
  }
}
