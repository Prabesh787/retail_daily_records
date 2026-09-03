import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../dashboard/views/dashboard_view.dart';
import '../../more/views/more_view.dart';
import '../../purchases/views/purchases_view.dart';
import '../../sales/views/sales_view.dart';
import '../../suppliers/views/suppliers_view.dart';
import '../controllers/home_controller.dart';

/// The five destinations, matching the web app's tab bar.
///
/// Five is the practical ceiling for a thumb-reachable bar; everything else —
/// customers, the cheque register, fiscal years — lives under More rather than
/// being squeezed in.
///
/// All five are real screens now; the shell does nothing but hold them and
/// remember which one is showing.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const List<({IconData icon, IconData active, String label})>
      _tabs = [
    (
      icon: Icons.dashboard_outlined,
      active: Icons.dashboard_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.receipt_long_outlined,
      active: Icons.receipt_long_rounded,
      label: 'Purchases',
    ),
    (
      icon: Icons.point_of_sale_outlined,
      active: Icons.point_of_sale_rounded,
      label: 'Sales',
    ),
    (
      icon: Icons.storefront_outlined,
      active: Icons.storefront_rounded,
      label: 'Suppliers',
    ),
    (
      icon: Icons.more_horiz_rounded,
      active: Icons.more_horiz_rounded,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // An IndexedStack, so a half-filtered list survives a trip to another tab
      // and back — a search typed on Suppliers is still there after a look at
      // the dashboard.
      body: Obx(
        () => IndexedStack(
          index: controller.tabIndex.value,
          children: [
            const DashboardView(),
            const PurchasesView(),
            const SalesView(),
            const SuppliersView(),
            const MoreView(),
          ],
        ),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: controller.changeTab,
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.active),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}
