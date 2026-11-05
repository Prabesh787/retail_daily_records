import 'package:get/get.dart';

/// The bottom-nav shell.
///
/// Tabs keep their state because the pages live in an [IndexedStack]: switching
/// away from a half-filtered list and back does not reset it, which is what a
/// shopkeeper flipping between screens mid-sale expects.
class HomeController extends GetxController {
  /// Named, so a screen elsewhere that switches tab does not break when the
  /// order changes.
  static const int homeTab = 0;
  static const int transactionsTab = 1;
  static const int partiesTab = 2;
  static const int accountsTab = 3;

  final RxInt tabIndex = 0.obs;

  void changeTab(int index) => tabIndex.value = index;
}
