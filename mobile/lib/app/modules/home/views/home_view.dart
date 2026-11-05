import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../accounts/views/accounts_view.dart';
import '../../activity/views/activity_view.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../more/views/more_view.dart';
import '../../parties/views/parties_view.dart';
import '../controllers/home_controller.dart';

/// The five destinations: what happened, who with, and where the money is.
///
/// Sales and purchases share History rather than each taking a tab, which
/// is what leaves room for Parties and Accounts. Their own lists, along with
/// everything else that does not earn a tab, live under More.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const List<({IconData icon, IconData active, String label})>
      _tabs = [
    (
      icon: Icons.home_outlined,
      active: Icons.home_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.receipt_long_outlined,
      active: Icons.receipt_long_rounded,
      // Short on purpose: 'Transactions' wraps onto two lines in a five-tab bar.
      label: 'History',
    ),
    (
      icon: Icons.people_outline_rounded,
      active: Icons.people_rounded,
      label: 'Parties',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      active: Icons.account_balance_wallet_rounded,
      label: 'Accounts',
    ),
    (
      icon: Icons.grid_view_outlined,
      active: Icons.grid_view_rounded,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // An IndexedStack, so a half-filtered list survives a trip to another tab
      // and back — a search typed on Parties is still there after a look at
      // the home screen.
      body: Obx(
        () => IndexedStack(
          index: controller.tabIndex.value,
          children: const [
            DashboardView(),
            ActivityView(),
            PartiesView(),
            AccountsView(),
            MoreView(),
          ],
        ),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: controller.changeTab,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
