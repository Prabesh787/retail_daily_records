import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../services/auth_service.dart';
import '../controllers/home_controller.dart';

/// The five destinations, matching the web app's tab bar.
///
/// Five is the practical ceiling for a thumb-reachable bar; everything else —
/// customers, the cheque register, fiscal years — lives under More rather than
/// being squeezed in.
///
/// Each tab is filled in as its screens are built. The placeholder below states
/// plainly what is coming rather than showing an empty page, because a blank
/// tab reads as a bug.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const List<({IconData icon, IconData active, String label, String note})>
      _tabs = [
    (
      icon: Icons.dashboard_outlined,
      active: Icons.dashboard_rounded,
      label: 'Home',
      note: 'Today’s takings, what you owe, and the next cheque due.',
    ),
    (
      icon: Icons.receipt_long_outlined,
      active: Icons.receipt_long_rounded,
      label: 'Purchases',
      note: 'Wholesale bills, grouped by the day they were entered.',
    ),
    (
      icon: Icons.point_of_sale_outlined,
      active: Icons.point_of_sale_rounded,
      label: 'Sales',
      note: 'Each sale on its own row, with the day’s takings on the header.',
    ),
    (
      icon: Icons.storefront_outlined,
      active: Icons.storefront_rounded,
      label: 'Suppliers',
      note: 'Ordered by what is owed, with a statement per supplier.',
    ),
    (
      icon: Icons.more_horiz_rounded,
      active: Icons.more_horiz_rounded,
      label: 'More',
      note: 'Cheque register, customers, fiscal years and shop details.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => IndexedStack(
          index: controller.tabIndex.value,
          children: [
            for (final tab in _tabs) _Placeholder(tab: tab),
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

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.tab});

  final ({IconData icon, IconData active, String label, String note}) tab;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = AuthService.to;

    return Scaffold(
      appBar: AppBar(
        title: Text(tab.label),
        actions: [
          Center(
            child: Text(
              auth.shopName,
              style: AppTextStyles.caption.copyWith(color: palette.inkSubtle),
            ),
          ),
          AppSizes.gapSm,
          // Temporary: the real sign-out belongs on the More tab. It is here so
          // the login flow can be exercised before that screen exists.
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () => auth.signOut(),
          ),
          AppSizes.gapSm,
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: AppCard(
            padding: const EdgeInsets.all(AppSizes.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconPlate(icon: tab.active, color: palette.brand, size: 52),
                AppSizes.gapLg,
                Text(tab.label, style: AppTextStyles.h2.copyWith(color: palette.ink)),
                AppSizes.gapSm,
                Text(
                  tab.note,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: palette.inkMuted),
                ),
                AppSizes.gapLg,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.xs,
                  ),
                  decoration: BoxDecoration(
                    color: palette.pendingSoft,
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  ),
                  child: Text(
                    'Being built',
                    style: AppTextStyles.label.copyWith(color: palette.pending),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
