import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../controllers/customers_controller.dart';

/// The customer list.
///
/// A pushed route rather than a tab: customers matter to a shop that invoices,
/// and not at all to one selling over a counter for cash. It lives under More
/// for the same reason the cheque register does.
class CustomersView extends GetView<CustomersController> {
  const CustomersView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Customers',
      back: true,
      padded: false,
      onRefresh: controller.reload,
      headerExtra: SearchField(
        hint: 'Name or phone',
        onChanged: (value) => controller.search.value = value,
      ),
      floatingAction: AppFab(
        label: 'New customer',
        onPressed: controller.createCustomer,
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
              if (controller.isEmpty)
                EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: controller.isSearching
                      ? 'No customers match'
                      : 'No customers yet',
                  message: controller.isSearching
                      ? 'Try part of the name, or the phone number.'
                      : 'Add the people you invoice. A walk-in paying cash '
                            'does not need a record.',
                  actionLabel:
                      controller.isSearching ? null : 'New customer',
                  onAction: controller.createCustomer,
                )
              else ...[
                StatTile(
                  icon: Icons.people_rounded,
                  label: 'SOLD TO THESE CUSTOMERS',
                  value: controller.total.display(decimals: false),
                  foot: '${controller.rows.length} '
                      'customer${controller.rows.length == 1 ? '' : 's'}',
                ),
                AppSizes.gapMd,
                AppCard.flush(
                  child: Column(
                    children: [
                      for (var i = 0; i < controller.rows.length; i++) ...[
                        if (i > 0) const RowDivider(),
                        CustomerRow(
                          customer: controller.rows[i],
                          onTap: () =>
                              controller.openCustomer(controller.rows[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
