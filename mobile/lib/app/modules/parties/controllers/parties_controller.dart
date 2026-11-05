import 'package:get/get.dart';

/// Which half of the Parties tab is showing.
enum PartyTab { customers, suppliers }

class PartiesController extends GetxController {
  final Rx<PartyTab> tab = PartyTab.customers.obs;

  void setTab(PartyTab value) => tab.value = value;
}
