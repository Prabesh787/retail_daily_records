import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/supplier_payment.dart';
import '../controllers/cheque_register_controller.dart';

/// The cheque register.
///
/// Every row here is money already counted against a supplier's balance but
/// still sitting in the account. Overdue and due-this-week are split out
/// because those are the two buckets that need doing something about today.
class ChequeRegisterView extends GetView<ChequeRegisterController> {
  const ChequeRegisterView({super.key});

  static const List<Segment<bool>> _filters = [
    Segment(value: true, label: 'Not cleared'),
    Segment(value: false, label: 'All cheques'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Cheque register',
      back: true,
      onRefresh: controller.reload,
      child: Obx(() {
        if (controller.isLoading.value) return const SkeletonRows();

        final message = controller.error.value;
        if (message != null) {
          return ErrorView(message: message, onRetry: controller.reload);
        }

        final split = controller.buckets;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedControl<bool>(
              segments: _filters,
              value: controller.onlyPending.value,
              onChanged: controller.setOnlyPending,
            ),
            AppSizes.gapMd,

            if (controller.isEmpty)
              EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: controller.onlyPending.value
                    ? 'Nothing outstanding'
                    : 'No cheques recorded',
                message: controller.onlyPending.value
                    ? 'Every cheque you have written has cleared the bank.'
                    : 'Cheques written to suppliers will be listed here.',
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.schedule_rounded,
                      label: 'DUE WITHIN 7 DAYS',
                      value: controller.dueThisWeek.display(decimals: false),
                      foot:
                          '${split.overdue.length + split.week.length} to cover',
                      tone: MoneyTone.pending,
                    ),
                  ),
                  AppSizes.gapMd,
                  Expanded(
                    child: StatTile(
                      icon: Icons.account_balance_outlined,
                      label: 'TOTAL LISTED',
                      value: controller.total.display(decimals: false),
                      foot: '${controller.rows.length} cheques',
                    ),
                  ),
                ],
              ),
              AppSizes.gapLg,

              _Bucket(
                label: 'Overdue',
                hint: 'Past the date on the cheque and still not cleared.',
                rows: split.overdue,
                controller: controller,
                tone: MoneyTone.outbound,
              ),
              _Bucket(
                label: 'Next 7 days',
                hint: 'Make sure the money is in the account.',
                rows: split.week,
                controller: controller,
                tone: MoneyTone.pending,
              ),
              _Bucket(
                label: 'Later',
                rows: split.later,
                controller: controller,
              ),
            ],
            AppSizes.gapXl,
          ],
        );
      }),
    );
  }
}

/// One bucket. Absent entirely when empty — an empty "Overdue" heading is a
/// small piece of good news that reads as a bug.
class _Bucket extends StatelessWidget {
  const _Bucket({
    required this.label,
    required this.rows,
    required this.controller,
    this.hint,
    this.tone = MoneyTone.plain,
  });

  final String label;
  final String? hint;
  final List<SupplierPayment> rows;
  final ChequeRegisterController controller;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${label.toUpperCase()} (${rows.length})',
                  style: AppTextStyles.label.copyWith(
                    color: tone == MoneyTone.plain
                        ? palette.inkSubtle
                        : tone.ink(palette),
                  ),
                ),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.xs),
              child: Text(
                hint!,
                style: AppTextStyles.caption.copyWith(
                  color: palette.inkSubtle,
                ),
              ),
            ),
          AppSizes.gapXs,
          AppCard.flush(
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  ChequeRow(
                    payment: rows[i],
                    onTap: () => controller.openPayment(rows[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
