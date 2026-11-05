import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/widgets.dart';
import '../../customers/views/customers_view.dart';
import '../../suppliers/views/suppliers_view.dart';
import '../controllers/parties_controller.dart';

/// The Parties tab: everyone the shop has an account with, on one tab.
///
/// Customers and suppliers are still separate records underneath; see
/// `docs/UI_UPGRADE.md` for what merging them would take. An [IndexedStack] so
/// each half keeps its search and scroll position.
class PartiesView extends GetView<PartiesController> {
  const PartiesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => IndexedStack(
        index: controller.tab.value.index,
        children: const [
          CustomersView(switcher: PartySwitcher()),
          SuppliersView(switcher: PartySwitcher()),
        ],
      ),
    );
  }
}

/// Pinned at the top of both halves.
class PartySwitcher extends GetView<PartiesController> {
  const PartySwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SegmentedControl<PartyTab>(
        segments: const [
          Segment(value: PartyTab.customers, label: 'Customers'),
          Segment(value: PartyTab.suppliers, label: 'Suppliers'),
        ],
        value: controller.tab.value,
        onChanged: controller.setTab,
      ),
    );
  }
}
