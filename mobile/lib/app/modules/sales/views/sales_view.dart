import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/sale_type.dart';
import '../controllers/sales_controller.dart';

/// Sales, grouped by day.
///
/// The day header is tappable, because the question a shopkeeper asks at
/// closing is about the day rather than about any one sale in it.
class SalesView extends GetView<SalesController> {
  const SalesView({super.key});

  static const List<Segment<SaleType?>> _filters = [
    Segment(value: null, label: 'All'),
    Segment(value: SaleType.summary, label: 'Total only'),
    Segment(value: SaleType.detailed, label: 'Itemised'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Sales',
      padded: false,
      onRefresh: controller.reload,
      headerExtra: SearchField(
        hint: 'Invoice, customer or item',
        onChanged: (value) => controller.search.value = value,
      ),
      floatingAction: AppFab(
        label: 'New sale',
        onPressed: controller.createSale,
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
              SegmentedControl<SaleType?>(
                segments: _filters,
                value: controller.typeFilter.value,
                onChanged: controller.setTypeFilter,
              ),
              AppSizes.gapMd,

              if (controller.isEmpty)
                EmptyState(
                  icon: Icons.point_of_sale_outlined,
                  title: controller.isFiltered
                      ? 'No sales match'
                      : 'No sales yet',
                  message: controller.isFiltered
                      ? 'Try the invoice number, or the customer’s name.'
                      : 'Record what the shop sold and the day’s takings build '
                            'up here.',
                  actionLabel: controller.isFiltered
                      ? 'Clear filters'
                      : 'New sale',
                  onAction: controller.isFiltered
                      ? controller.clearFilters
                      : controller.createSale,
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.point_of_sale_rounded,
                        label: 'SOLD',
                        value: controller.total.display(decimals: false),
                        foot: '${controller.rows.length} sales',
                      ),
                    ),
                    AppSizes.gapMd,
                    Expanded(
                      // Separate from "sold" on purpose: a day that sold well
                      // on credit is a good day and a bad till, and the list
                      // should not have to choose which of those to report.
                      child: StatTile(
                        icon: Icons.payments_rounded,
                        label: 'TAKEN',
                        value: controller.received.display(decimals: false),
                        foot: 'Credit excluded',
                        tone: MoneyTone.inbound,
                      ),
                    ),
                  ],
                ),
                AppSizes.gapMd,

                for (final group in controller.groups) ...[
                  AppCard.flush(
                    child: Column(
                      children: [
                        GroupHeader(
                          label: AppDateUtils.relativeDay(group.dateMs),
                          total: group.total,
                          onTap: () => controller.openDay(group.dateMs),
                        ),
                        for (var i = 0; i < group.rows.length; i++) ...[
                          if (i > 0) const RowDivider(),
                          SaleRow(
                            sale: group.rows[i],
                            onTap: () => controller.openSale(group.rows[i]),
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
