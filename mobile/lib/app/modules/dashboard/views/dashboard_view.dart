import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/sync_status_chip.dart';

/// The home screen.
///
/// Every figure here is a summary of rows that live on another screen, and
/// every one of them is tappable through to those rows. That is the rule the
/// screen is built to: a dashboard whose numbers cannot be checked is a
/// dashboard nobody ends up trusting.
class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: controller.greeting,
      eyebrow: controller.shopName,
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
              Skeleton(height: 190, radius: AppSizes.radiusCard),
              AppSizes.gapMd,
              Skeleton(height: 96, radius: AppSizes.radiusCard),
              AppSizes.gapMd,
              Skeleton(height: 220, radius: AppSizes.radiusCard),
            ],
          );
        }

        final message = controller.error.value;
        final board = controller.board;
        if (message != null || board == null) {
          return ErrorView(
            message: message ?? 'The dashboard could not be loaded.',
            onRetry: controller.reload,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TodayCard(board: board, controller: controller),
            AppSizes.gapMd,

            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'PAYABLE TO SUPPLIERS',
                    value: board.payableTotal.display(decimals: false),
                    foot: '${board.payableSupplierCount} '
                        'supplier${board.payableSupplierCount == 1 ? '' : 's'}',
                    tone: MoneyTone.outbound,
                    onTap: controller.openSuppliers,
                  ),
                ),
                AppSizes.gapMd,
                Expanded(
                  child: StatTile(
                    icon: Icons.schedule_rounded,
                    label: 'CHEQUES NOT CLEARED',
                    value: board.unclearedTotal.display(decimals: false),
                    foot: '${board.unclearedCount} awaiting',
                    tone: MoneyTone.pending,
                    onTap: controller.openCheques,
                  ),
                ),
              ],
            ),
            AppSizes.gapMd,

            if (board.nextCheque case final cheque?) ...[
              _NextCheque(cheque: cheque, onOpen: controller.openCheques),
              AppSizes.gapMd,
            ],

            _QuickActions(controller: controller),
            AppSizes.gapLg,

            if (board.topOwed.isNotEmpty) ...[
              SectionHeader(
                title: 'OWED THE MOST',
                action: 'All suppliers',
                onAction: controller.openSuppliers,
              ),
              AppCard.flush(
                child: Column(
                  children: [
                    for (var i = 0; i < board.topOwed.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      SupplierRow(
                        supplier: board.topOwed[i],
                        onTap: () =>
                            controller.openSupplier(board.topOwed[i].id),
                      ),
                    ],
                  ],
                ),
              ),
              AppSizes.gapLg,
            ],

            if (board.latestSales.isNotEmpty) ...[
              SectionHeader(
                title: 'LATEST SALES',
                action: 'All sales',
                onAction: controller.openSales,
              ),
              AppCard.flush(
                child: Column(
                  children: [
                    for (var i = 0; i < board.latestSales.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      SaleRow(
                        sale: board.latestSales[i],
                        onTap: () =>
                            controller.openSale(board.latestSales[i].id),
                      ),
                    ],
                  ],
                ),
              ),
              AppSizes.gapLg,
            ],

            if (board.latestBills.isNotEmpty) ...[
              SectionHeader(
                title: 'LATEST BILLS',
                action: 'All purchases',
                onAction: controller.openPurchases,
              ),
              AppCard.flush(
                child: Column(
                  children: [
                    for (var i = 0; i < board.latestBills.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      PurchaseRow(
                        purchase: board.latestBills[i],
                        onTap: () =>
                            controller.openBill(board.latestBills[i].id),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (board.isFresh) _Welcome(controller: controller),
            AppSizes.gapXl,
          ],
        );
      }),
    );
  }
}

/// Today's takings and the fortnight behind them.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.board, required this.controller});

  final DashboardData board;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALES TODAY',
                      style: AppTextStyles.label.copyWith(
                        color: palette.inkSubtle,
                      ),
                    ),
                    Text(
                      board.todaySales.display(),
                      style: AppTextStyles.display.copyWith(
                        color: palette.moneyIn,
                      ),
                    ),
                    Text(
                      // Credit is named rather than folded in, the same rule
                      // the day book follows — a good day on credit is not
                      // money in the till.
                      board.todayOnCredit.isPositive
                          ? '${board.todayCount} sale'
                                '${board.todayCount == 1 ? '' : 's'} · '
                                '${board.todayOnCredit.display(decimals: false)}'
                                ' on credit'
                          : '${board.todayCount} sale'
                                '${board.todayCount == 1 ? '' : 's'}, all '
                                'settled',
                      style: AppTextStyles.caption.copyWith(
                        color: board.todayOnCredit.isPositive
                            ? palette.pending
                            : palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open today',
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: controller.openToday,
              ),
            ],
          ),
          AppSizes.gapMd,
          TrendChart(points: board.trend),
        ],
      ),
    );
  }
}

/// The next cheque that needs money in the account.
class _NextCheque extends StatelessWidget {
  const _NextCheque({required this.cheque, required this.onOpen});

  final SupplierPayment cheque;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final due = cheque.chequeDate ?? cheque.paymentDate;
    final days = AppDateUtils.daysUntil(due);

    final overdue = days < 0;
    final tone = overdue ? palette.moneyOut : palette.pending;

    return Material(
      color: overdue ? palette.moneyOutSoft : palette.pendingSoft,
      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Row(
            children: [
              Icon(
                overdue
                    ? Icons.error_outline_rounded
                    : Icons.event_available_outlined,
                size: 20,
                color: tone,
              ),
              AppSizes.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overdue
                          ? 'A cheque is overdue'
                          : days == 0
                              ? 'A cheque is dated today'
                              : 'Next cheque in $days day'
                                  '${days == 1 ? '' : 's'}',
                      style: AppTextStyles.bodyStrong.copyWith(color: tone),
                    ),
                    Text(
                      '${cheque.amount.display(decimals: false)} to '
                      '${cheque.supplierName ?? 'a supplier'} · '
                      '${AppDateUtils.formatDate(due)}',
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
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        _Action(
          icon: Icons.point_of_sale_rounded,
          label: 'Sale',
          color: palette.moneyIn,
          onTap: controller.newSale,
        ),
        AppSizes.gapMd,
        _Action(
          icon: Icons.receipt_long_rounded,
          label: 'Bill',
          color: palette.moneyOut,
          onTap: controller.newPurchase,
        ),
        AppSizes.gapMd,
        _Action(
          icon: Icons.payments_rounded,
          label: 'Payment',
          color: palette.brand,
          onTap: controller.newPayment,
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Expanded(
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            decoration: BoxDecoration(
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            ),
            child: Column(
              children: [
                Icon(icon, size: 22, color: color),
                AppSizes.gapXs,
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
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
      message: 'Start with a sale or a wholesale bill. Everything on this '
          'screen fills in from what you enter.',
      actionLabel: 'Record a sale',
      onAction: controller.newSale,
    );
  }
}
