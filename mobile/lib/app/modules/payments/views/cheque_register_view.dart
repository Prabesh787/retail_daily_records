import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/ledger.dart';
import '../controllers/cheque_register_controller.dart';

/// The cheque register, both ways.
///
/// Overdue and due-this-week are split out because those are the two buckets
/// that need doing something about today.
class ChequeRegisterView extends GetView<ChequeRegisterController> {
  const ChequeRegisterView({super.key});

  static const List<Segment<ChequeDirection?>> _directions = [
    Segment(value: null, label: 'All'),
    Segment(value: ChequeDirection.toCollect, label: 'To collect'),
    Segment(value: ChequeDirection.toPay, label: 'To pay'),
  ];

  static const List<Segment<bool>> _filters = [
    Segment(value: true, label: 'Not cleared'),
    Segment(value: false, label: 'All cheques'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Cheques',
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
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'TO COLLECT',
                    value: controller.toCollect.display(decimals: false),
                    tone: MoneyTone.inbound,
                  ),
                ),
                AppSizes.gapSm,
                Expanded(
                  child: StatTile(
                    label: 'TO PAY',
                    value: controller.toPay.display(decimals: false),
                    tone: MoneyTone.outbound,
                  ),
                ),
              ],
            ),
            AppSizes.gapMd,
            SegmentedControl<ChequeDirection?>(
              segments: _directions,
              value: controller.direction.value,
              onChanged: controller.setDirection,
            ),
            AppSizes.gapSm,
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
                    ? 'Every cheque has cleared.'
                    : 'Cheques you receive or write will be listed here.',
              )
            else ...[
              _Bucket(
                label: 'Overdue',
                rows: split.overdue,
                controller: controller,
                tone: MoneyTone.outbound,
              ),
              _Bucket(
                label: 'Next 7 days',
                rows: split.week,
                controller: controller,
                tone: MoneyTone.pending,
              ),
              _Bucket(
                label: 'Later',
                rows: split.later,
                controller: controller,
              ),
              _Bucket(
                label: 'Cleared or cancelled',
                rows: split.settled,
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
    this.tone = MoneyTone.plain,
  });

  final String label;
  final List<ChequeItem> rows;
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
          Text(
            '${label.toUpperCase()} (${rows.length})',
            style: AppTextStyles.label.copyWith(
              color: tone == MoneyTone.plain
                  ? palette.inkSubtle
                  : tone.ink(palette),
            ),
          ),
          AppSizes.gapXs,
          AppCard.flush(
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  ChequeRow(
                    cheque: rows[i],
                    onTap: () => _actions(context, rows[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A pending cheque has something to do; a settled one is just a record.
  Future<void> _actions(BuildContext context, ChequeItem cheque) async {
    if (!cheque.isPending) {
      controller.open(cheque);
      return;
    }

    final toCollect = cheque.direction == ChequeDirection.toCollect;
    final action = await AppSheet.options<_Action>(
      context: context,
      title: 'Cheque ${cheque.chequeNo ?? ''}'.trim(),
      options: [
        const SheetOption(value: _Action.clear, label: 'Mark as cleared'),
        SheetOption(
          value: _Action.bounce,
          label: toCollect ? 'It bounced' : 'Cancel cheque',
        ),
        const SheetOption(value: _Action.open, label: 'View details'),
      ],
    );
    if (!context.mounted) return;

    switch (action) {
      case _Action.clear:
        await controller.clear(context, cheque);
      case _Action.bounce:
        await controller.bounce(cheque);
      case _Action.open:
        controller.open(cheque);
      case null:
        break;
    }
  }
}

enum _Action { clear, bounce, open }
