import 'package:get/get.dart';

/// The bottom-nav shell.
///
/// Tabs keep their state because the pages live in an [IndexedStack]: switching
/// away from a half-filtered list and back does not reset it, which is what a
/// shopkeeper flipping between screens mid-sale expects.
class HomeController extends GetxController {
  final RxInt tabIndex = 0.obs;

  void changeTab(int index) => tabIndex.value = index;
}
