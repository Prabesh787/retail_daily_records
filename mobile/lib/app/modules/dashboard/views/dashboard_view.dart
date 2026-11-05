import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/domain/money.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/ledger.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/sync_status_chip.dart';

/// The home screen.
///
/// Answers three questions in order: where do I stand, what needs doing today,
/// and what do I want to enter next. Every figure here is a summary of rows that
/// live on another screen, and every one of them is tappable through to those
/// rows, because a dashboard whose numbers cannot be checked is a dashboard
/// nobody ends up trusting.
class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: controller.shopName,
      onRefresh: controller.reload,
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: AppSizes.lg),
          child: Center(child: SyncStatusChip()),
        ),
      ],
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Column(
            children: [
              Skeleton(height: 96, radius: AppSizes.radiusCard),
              AppSizes.gapMd,
              Skeleton(height: 170, radius: AppSizes.radiusCard),
              AppSizes.gapMd,
              Skeleton(height: 220, radius: AppSizes.radiusCard),
            ],
          );
        }

        final message = controller.error.value;
        final board = controller.board;
        if (message != null || board == null) {
          return ErrorView(
            message: message ?? 'The home screen could not be loaded.',
            onRetry: controller.reload,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Standing(board: board, controller: controller),
            AppSizes.gapSm,
            _ChequeReminder(board: board, onOpen: controller.openCheques),
            _Shortcuts(controller: controller),
            AppSizes.gapMd,
            _Today(board: board, onOpen: controller.openToday),
            AppSizes.gapMd,

            if (board.recent.isNotEmpty) ...[
              SectionHeader(
                title: 'RECENT',
                action: 'See all',
                onAction: controller.openTransactions,
              ),
              AppCard.flush(
                child: Column(
                  children: [
                    for (var i = 0; i < board.recent.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      ActivityRow(
                        item: board.recent[i],
                        onTap: () => controller.open(board.recent[i]),
                      ),
                    ],
                  ],
                ),
              ),
              AppSizes.gapMd,
              const SectionHeader(title: 'SALES, LAST 14 DAYS'),
              AppCard(child: TrendChart(points: board.trend)),
            ],

            if (board.isFresh) _Welcome(controller: controller),
            AppSizes.gapLg,
          ],
        );
      }),
    );
  }
}

/// Four numbers that say where the shop stands: who owes whom, and what is in
/// hand.
class _Standing extends StatelessWidget {
  const _Standing({required this.board, required this.controller});

  final DashboardData board;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Figure(
                label: 'To receive',
                value: board.receivableTotal,
                tone: MoneyTone.inbound,
                onTap: controller.openCustomers,
              ),
            ),
            AppSizes.gapSm,
            Expanded(
              child: _Figure(
                label: 'To pay',
                value: board.payableTotal,
                tone: MoneyTone.outbound,
                onTap: controller.openSuppliers,
              ),
            ),
          ],
        ),
        AppSizes.gapSm,
        Row(
          children: [
            Expanded(
              child: _Figure(
                label: 'Cash in hand',
                value: board.cashBalance,
                onTap: controller.openAccounts,
              ),
            ),
            AppSizes.gapSm,
            Expanded(
              child: _Figure(
                label: 'In bank',
                value: board.bankBalance,
                onTap: controller.openAccounts,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A coloured figure tile. Tinted for the two that carry a direction.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.onTap,
    this.tone = MoneyTone.plain,
  });

  final String label;
  final Money value;
  final VoidCallback onTap;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = tone.ink(palette);
    final ground = switch (tone) {
      MoneyTone.inbound => palette.moneyInSoft,
      MoneyTone.outbound => palette.moneyOutSoft,
      _ => palette.surface,
    };

    return Material(
      color: ground,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value.display(decimals: false),
                  style: AppTextStyles.h2.copyWith(
                    color: value.isNegative ? palette.moneyOut : ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The in-app cheque reminder: overdue, or due within the week, in both
/// directions. Absent when there is nothing to do.
class _ChequeReminder extends StatelessWidget {
  const _ChequeReminder({required this.board, required this.onOpen});

  final DashboardData board;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final reminders = board.chequeReminders;
    if (reminders.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;
    final overdue = reminders.where((c) => c.daysLeft < 0).length;
    final toCollect = reminders.where(
      (c) => c.direction == ChequeDirection.toCollect,
    );
    final toPay = reminders.where((c) => c.direction == ChequeDirection.toPay);
    final tone = overdue > 0 ? palette.moneyOut : palette.pending;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: overdue > 0 ? palette.moneyOutSoft : palette.pendingSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            child: Row(
              children: [
                Icon(
                  overdue > 0
                      ? Icons.error_outline_rounded
                      : Icons.event_available_outlined,
                  size: 20,
                  color: tone,
                ),
                AppSizes.gapSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overdue > 0
                            ? '$overdue cheque${overdue == 1 ? ' is' : 's are'} overdue'
                            : '${reminders.length} cheque'
                                  '${reminders.length == 1 ? '' : 's'} this week',
                        style: AppTextStyles.bodyStrong.copyWith(color: tone),
                      ),
                      Text(
                        [
                          if (toCollect.isNotEmpty)
                            'Collect ${_sum(toCollect)}',
                          if (toPay.isNotEmpty) 'Pay ${_sum(toPay)}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: palette.inkSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sum(Iterable<ChequeItem> cheques) =>
      Money.sum(cheques.map((c) => c.amount)).display(decimals: false);
}

/// Everything the shopkeeper starts from here, in one grid: four a row, so eight
/// choices cost two lines.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final items = <_Shortcut>[
      _Shortcut(
        Icons.calculate_rounded,
        'Quick Sale',
        palette.moneyIn,
        controller.newQuickSale,
      ),
      _Shortcut(
        ActivityKind.sale.icon,
        'Sale',
        palette.moneyIn,
        controller.newSale,
      ),
      _Shortcut(
        ActivityKind.paymentIn.icon,
        'Payment In',
        palette.moneyIn,
        controller.newPaymentIn,
      ),
      _Shortcut(
        Icons.person_add_alt_1_rounded,
        'Customer',
        palette.brand,
        controller.newCustomer,
      ),
      _Shortcut(
        ActivityKind.purchase.icon,
        'Purchase',
        palette.moneyOut,
        controller.newPurchase,
      ),
      _Shortcut(
        ActivityKind.paymentOut.icon,
        'Payment Out',
        palette.moneyOut,
        controller.newPaymentOut,
      ),
      _Shortcut(
        Icons.store_mall_directory_rounded,
        'Supplier',
        palette.brand,
        controller.newSupplier,
      ),
      _Shortcut(
        Icons.account_balance_wallet_rounded,
        'Cheques',
        palette.pending,
        controller.openCheques,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.xs,
        vertical: AppSizes.sm,
      ),
      child: Column(
        children: [
          for (final row in [items.sublist(0, 4), items.sublist(4)])
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in row) Expanded(child: _ShortcutTile(item)),
              ],
            ),
        ],
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile(this.item);

  final _Shortcut item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radius),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
        child: Column(
          children: [
            IconPlate(icon: item.icon, color: item.color, size: 42),
            AppSizes.gapXs,
            Text(
              item.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today in one line: what was sold, and the money that actually moved.
class _Today extends StatelessWidget {
  const _Today({required this.board, required this.onOpen});

  final DashboardData board;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _TodayFigure(
              label: 'Sold today',
              value: board.todaySales,
              tone: MoneyTone.plain,
            ),
          ),
          Expanded(
            child: _TodayFigure(
              label: 'Money in',
              value: board.todayIn,
              tone: MoneyTone.inbound,
            ),
          ),
          Expanded(
            child: _TodayFigure(
              label: 'Money out',
              value: board.todayOut,
              tone: MoneyTone.outbound,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayFigure extends StatelessWidget {
  const _TodayFigure({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final Money value;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: palette.inkSubtle,
            fontWeight: FontWeight.w500,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value.display(decimals: false),
            style: AppTextStyles.amountSmall.copyWith(
              fontSize: 15,
              color: tone.ink(palette),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown to a shop that has recorded nothing at all — a different thing from a
/// quiet day, and worth saying differently.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.waving_hand_outlined,
      title: 'Nothing recorded yet',
      message: 'Start with a Quick Sale. Everything on this screen fills in '
          'from what you enter.',
      actionLabel: 'Quick Sale',
      onAction: controller.newQuickSale,
    );
  }
}
