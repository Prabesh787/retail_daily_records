import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/ledger.dart';
import '../../../routes/app_pages.dart';
import '../controllers/activity_controller.dart';

/// The History tab.
///
/// One list for all four documents, told apart by colour and icon, with the two
/// commonest entries pinned where a thumb already is. Everything else is behind
/// the middle button.
class ActivityView extends GetView<ActivityController> {
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'History',
      padded: false,
      onRefresh: controller.reload,
      headerExtra: Row(
        children: [
          Expanded(
            child: SearchField(
              hint: 'Name or number',
              onChanged: (value) => controller.search.value = value,
            ),
          ),
          AppSizes.gapSm,
          Obx(
            () => IconButton.filledTonal(
              tooltip: 'Filter by date',
              isSelected: !controller.range.value.isAll,
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              onPressed: () => _pickRange(context),
            ),
          ),
        ],
      ),
      bottomBar: const _ActionBar(),
      child: Obx(() {
        if (controller.isLoading.value) return const SkeletonRows();

        final message = controller.error.value;
        if (message != null) {
          return ErrorView(message: message, onRetry: controller.reload);
        }

        final rows = controller.rows;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KindChips(selected: controller.kind.value, onTap: controller.setKind),

            if (controller.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: controller.isFiltered
                    ? 'Nothing matches'
                    : 'No transactions yet',
                message: controller.isFiltered
                    ? 'Try a different name, number or date.'
                    : 'Sales, purchases and payments all appear here.',
                actionLabel: controller.isFiltered ? 'Clear filters' : null,
                onAction: controller.isFiltered
                    ? controller.clearFilters
                    : null,
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  0,
                  AppSizes.lg,
                  AppSizes.lg,
                ),
                child: AppCard.flush(
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const RowDivider(),
                        ActivityRow(
                          item: rows[i],
                          onTap: () => controller.open(rows[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (controller.isAtLimit)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.lg),
                  child: Text(
                    'Showing the latest ${ActivityController.pageLimit}. Search '
                    'or pick dates to find older ones.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.inkSubtle,
                    ),
                  ),
                ),
            ],
          ],
        );
      }),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangeSheet(
      context: context,
      selected: controller.range.value,
    );
    if (picked != null) controller.setRange(picked);
  }
}

class _KindChips extends StatelessWidget {
  const _KindChips({required this.selected, required this.onTap});

  final ActivityKind? selected;
  final ValueChanged<ActivityKind?> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          _Chip(label: 'All', active: selected == null, onTap: () => onTap(null)),
          for (final kind in ActivityKind.values)
            _Chip(
              label: kind.label,
              active: selected == kind,
              color: kind.color(context.palette),
              onTap: () => onTap(kind),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.brand;

    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sm),
      child: Material(
        color: active ? tint : palette.surface,
        shape: StadiumBorder(
          side: BorderSide(color: active ? tint : palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: 7,
            ),
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : palette.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The two commonest entries in their own colours, and everything else one tap
/// behind the middle button.
class _ActionBar extends StatelessWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Sale',
            icon: ActivityKind.sale.icon,
            color: palette.moneyIn,
            onPressed: () => Get.toNamed<void>(Routes.saleForm),
          ),
        ),
        AppSizes.gapSm,
        IconButton.outlined(
          tooltip: 'More entries',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => showNewEntrySheet(context),
        ),
        AppSizes.gapSm,
        Expanded(
          child: AppButton(
            label: 'Purchase',
            icon: ActivityKind.purchase.icon,
            color: palette.moneyOut,
            onPressed: () => Get.toNamed<void>(Routes.purchaseForm),
          ),
        ),
      ],
    );
  }
}

/// Every kind of entry, in one place.
Future<void> showNewEntrySheet(BuildContext context) async {
  final route = await AppSheet.options<String>(
    context: context,
    title: 'New entry',
    options: const [
      SheetOption(value: Routes.quickSale, label: 'Quick Sale'),
      SheetOption(value: Routes.saleForm, label: 'Sale'),
      SheetOption(value: Routes.purchaseForm, label: 'Purchase'),
      SheetOption(value: Routes.receiptForm, label: 'Payment In'),
      SheetOption(value: Routes.paymentForm, label: 'Payment Out'),
    ],
  );
  if (route != null) await Get.toNamed<void>(route);
}
