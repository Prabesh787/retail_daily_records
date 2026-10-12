import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/supplier.dart';
import '../controllers/suppliers_controller.dart';

/// Suppliers, largest debt first.
///
/// The card above the list is the point of the screen: what the shop owes in
/// total, split into money already gone and cheques that have not cleared.
/// The list underneath is that number itemised.
class SuppliersView extends GetView<SuppliersController> {
  const SuppliersView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Suppliers',
      back: false,
      padded: false,
      onRefresh: controller.reload,
      headerExtra: SearchField(
        hint: 'Name or phone',
        onChanged: controller.onSearchChanged,
      ),
      floatingAction: AppFab(
        label: 'New supplier',
        onPressed: controller.createSupplier,
      ),
      child: Obx(() {
        if (controller.isLoading.value) return const SkeletonRows();

        final message = controller.error.value;
        if (message != null) {
          return ErrorView(message: message, onRetry: controller.reload);
        }

        return Padding(
          // Clears the FAB, so the last supplier is never trapped under it.
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.lg,
            AppSizes.lg,
            104,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BalanceCard(
                label: 'Total payable',
                amount: controller.totalOutstanding,
                cleared: controller.totalCleared,
                uncleared: controller.totalUncleared,
                caption: _caption(controller.rows.length),
              ),
              AppSizes.gapLg,
              if (controller.isEmpty)
                EmptyState(
                  icon: Icons.storefront_rounded,
                  title: controller.isSearching
                      ? 'No suppliers match'
                      : 'No suppliers yet',
                  message: controller.isSearching
                      ? 'Try part of the name, or the phone number.'
                      : 'Add the wholesalers you buy from and their balances '
                            'will build up here.',
                  actionLabel: controller.isSearching ? null : 'New supplier',
                  onAction: controller.createSupplier,
                )
              else if (controller.topRows.isEmpty)
                _SupplierList(rows: controller.rows, controller: controller)
              else ...[
                SectionHeader(
                  title: 'TOP SUPPLIERS (${controller.topRows.length})',
                ),
                _SupplierList(rows: controller.topRows, controller: controller),
                if (controller.otherRows.isNotEmpty) ...[
                  AppSizes.gapLg,
                  SectionHeader(
                    title: 'ALL OTHERS (${controller.otherRows.length})',
                  ),
                  _SupplierList(
                    rows: controller.otherRows,
                    controller: controller,
                  ),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }

  String _caption(int count) =>
      'Across $count supplier${count == 1 ? '' : 's'}';
}

class _SupplierList extends StatelessWidget {
  const _SupplierList({required this.rows, required this.controller});

  final List<Supplier> rows;
  final SuppliersController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard.flush(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const RowDivider(),
            SupplierRow(
              supplier: rows[i],
              onTap: () => controller.openSupplier(rows[i]),
            ),
          ],
        ],
      ),
    );
  }
}
