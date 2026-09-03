import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../controllers/purchases_controller.dart';

/// Wholesale bills, grouped by the day they were entered.
///
/// The group header carries the day's total, which is the number a shopkeeper
/// is actually scanning for — "what did I take on stock on Tuesday" is asked
/// far more often than "what was bill 4471".
class PurchasesView extends GetView<PurchasesController> {
  const PurchasesView({super.key});

  static const List<Segment<bool>> _filters = [
    Segment(value: false, label: 'All bills'),
    Segment(value: true, label: 'Unpaid'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Purchases',
      padded: false,
      onRefresh: controller.reload,
      headerExtra: SearchField(
        hint: 'Supplier, bill number or item',
        onChanged: (value) => controller.search.value = value,
      ),
      floatingAction: AppFab(
        label: 'New bill',
        onPressed: controller.createBill,
      ),
      child: Obx(() {
        if (controller.isLoading.value) return const SkeletonRows();

        final message = controller.error.value;
        if (message != null) {
          return ErrorView(message: message, onRetry: controller.reload);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.lg,
            AppSizes.lg,
            104,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedControl<bool>(
                segments: _filters,
                value: controller.onlyUnpaid.value,
                onChanged: controller.setOnlyUnpaid,
              ),
              AppSizes.gapMd,

              if (controller.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: controller.isFiltered
                      ? 'No bills match'
                      : 'No purchases yet',
                  message: controller.isFiltered
                      ? 'Try the supplier name, or the number printed on the '
                            'bill.'
                      : 'Record a wholesale bill and it will appear here, '
                            'grouped by the day you entered it.',
                  actionLabel: controller.isFiltered
                      ? 'Clear filters'
                      : 'New bill',
                  onAction: controller.isFiltered
                      ? controller.clearFilters
                      : controller.createBill,
                )
              else ...[
                _Summary(
                  controller: controller,
                  onlyUnpaid: controller.onlyUnpaid.value,
                ),
                AppSizes.gapMd,
                for (final group in controller.groups) ...[
                  AppCard.flush(
                    child: Column(
                      children: [
                        GroupHeader(
                          label: AppDateUtils.relativeDay(group.dateMs),
                          total: group.total,
                        ),
                        for (var i = 0; i < group.rows.length; i++) ...[
                          if (i > 0) const RowDivider(),
                          PurchaseRow(
                            purchase: group.rows[i],
                            onTap: () => controller.openBill(group.rows[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSizes.gapMd,
                ],
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// What the list adds up to, so the figure is not left to be inferred from
/// scrolling every day group.
///
/// Takes what it needs as plain values rather than reading observables itself.
///
/// This build runs outside the caller's `Obx` closure, so a `.value` read here
/// would not be tracked — it happens to work only because the caller reads the
/// same flag and rebuilds this widget with it. Passing it in makes that
/// dependency real instead of incidental.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.controller,
    required this.onlyUnpaid,
  });

  final PurchasesController controller;
  final bool onlyUnpaid;

  @override
  Widget build(BuildContext context) {
    final count = controller.rows.length;

    return StatTile(
      icon: Icons.receipt_long_rounded,
      label: onlyUnpaid ? 'UNPAID BILLS' : 'BILLS SHOWN',
      value: controller.total.display(decimals: false),
      foot: '$count bill${count == 1 ? '' : 's'}',
      tone: MoneyTone.outbound,
    );
  }
}
