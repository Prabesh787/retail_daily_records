import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/domain/money.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/payment_status.dart';
import '../../../data/providers/local/supplier_dao.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../controllers/supplier_statement_controller.dart';

/// The statement.
///
/// Movements oldest first with a running balance, opened by the position
/// carried in and closed by the position carried out. Read top to bottom it is
/// the arithmetic behind the balance, which is exactly what a supplier
/// disputing a figure needs to see.
class SupplierStatementView extends GetView<SupplierStatementController> {
  const SupplierStatementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final statement = controller.statement;

      return AppScreen(
        title: 'Statement',
        eyebrow: statement?.supplier.name,
        back: true,
        onRefresh: controller.reload,
        child: _body(context, statement),
      );
    });
  }

  Widget _body(BuildContext context, SupplierStatement? statement) {
    if (controller.isLoading.value) {
      return const Column(
        children: [
          Skeleton(height: 190, radius: AppSizes.radiusCard),
          AppSizes.gapLg,
          Skeleton(height: 260, radius: AppSizes.radiusCard),
        ],
      );
    }

    final message = controller.error.value;
    if (message != null || statement == null) {
      return ErrorView(
        message: message ?? 'This statement could not be loaded.',
        onRetry: controller.reload,
      );
    }

    final window = statement.window;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: DateRangeChip(
            range: controller.range.value,
            onTap: () => _pickRange(context),
          ),
        ),
        AppSizes.gapLg,

        _SummaryCard(window: window, range: controller.range.value),
        AppSizes.gapLg,

        AppCard.flush(
          child: Column(
            children: [
              _BalanceBand(
                label: 'Opening balance',
                amount: window.openingAsOf,
              ),

              if (statement.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Text(
                    'No movements in this range. The balance carried in is the '
                    'balance carried out.',
                    style: AppTextStyles.body.copyWith(
                      color: context.palette.inkMuted,
                    ),
                  ),
                )
              else
                for (final line in statement.lines) ...[
                  const RowDivider(full: true),
                  _StatementLine(line: line),
                ],

              const RowDivider(full: true),
              _BalanceBand(
                label: 'Closing balance',
                amount: window.closing,
                strong: true,
              ),
            ],
          ),
        ),
        AppSizes.gapXl,
      ],
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

/// The headline: what is owed at the end of the window, and the three figures
/// that got there.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.window, required this.range});

  final SupplierWindow window;
  final DateRange range;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final owes = window.closing.isPositive;

    final from = range.from;
    final to = range.to;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLOSING BALANCE',
            style: AppTextStyles.label.copyWith(color: palette.inkSubtle),
          ),
          Text(
            window.closing.display(),
            style: AppTextStyles.display.copyWith(
              color: owes ? palette.moneyOut : palette.moneyIn,
            ),
          ),
          Text(
            '${from == null ? 'Beginning' : AppDateUtils.formatDate(from)}'
            ' — ${to == null ? 'today' : AppDateUtils.formatDate(to)}',
            style: AppTextStyles.label.copyWith(
              color: palette.inkSubtle,
              fontWeight: FontWeight.w500,
            ),
          ),

          AppSizes.gapMd,
          const RowDivider(full: true),
          AppSizes.gapMd,

          Row(
            children: [
              _Figure(label: 'Opening', amount: window.openingAsOf),
              _Figure(
                label: 'Billed',
                amount: window.purchaseTotal,
                tone: MoneyTone.outbound,
              ),
              _Figure(
                label: 'Paid',
                amount: window.paymentTotal,
                tone: MoneyTone.inbound,
              ),
            ],
          ),

          // The one caveat that changes what the closing figure means for the
          // bank balance, so it is stated rather than left to be inferred.
          if (window.unclearedTotal.isPositive) ...[
            AppSizes.gapMd,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: BoxDecoration(
                color: palette.pendingSoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                '${window.unclearedTotal.display(decimals: false)} of the '
                'payments above are cheques that have not cleared the bank yet.',
                style: AppTextStyles.caption.copyWith(color: palette.pending),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One movement, with the balance it left behind.
class _StatementLine extends StatelessWidget {
  const _StatementLine({required this.line});

  final LedgerMovement line;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDebit = line.debit.isPositive;
    final status = line.status;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        line.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                    ),
                    // Cleared is the normal state and saying so on every line
                    // would be noise; anything else is worth flagging.
                    if (status != null && status != PaymentStatus.cleared) ...[
                      const SizedBox(width: 6),
                      PaymentStatusBadge(status),
                    ],
                  ],
                ),
                Text(
                  [
                    AppDateUtils.datePair(line.dateMs, line.dateBs),
                    ?line.detail,
                  ].where((part) => part.isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          AppSizes.gapMd,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isDebit
                    ? '+ ${line.debit.display(symbol: '', decimals: false)}'
                    : '− ${line.credit.display(symbol: '', decimals: false)}',
                style: AppTextStyles.amountSmall.copyWith(
                  color: isDebit ? palette.moneyOut : palette.moneyIn,
                ),
              ),
              Text(
                line.balance?.display(decimals: false) ?? '',
                style: AppTextStyles.label.copyWith(
                  color: palette.inkSubtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The bands that open and close the column.
class _BalanceBand extends StatelessWidget {
  const _BalanceBand({
    required this.label,
    required this.amount,
    this.strong = false,
  });

  final String label;
  final Money amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      color: palette.sunken,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: AppTextStyles.label.copyWith(
                color: strong ? palette.ink : palette.inkSubtle,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            amount.display(),
            style: AppTextStyles.amountSmall.copyWith(
              color: strong ? palette.ink : palette.inkMuted,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    this.tone = MoneyTone.plain,
  });

  final String label;
  final Money amount;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: AppTextStyles.label.copyWith(
              color: palette.inkSubtle,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            amount.display(decimals: false),
            maxLines: 1,
            style: AppTextStyles.amountSmall.copyWith(
              fontSize: 15,
              color: tone.ink(palette),
            ),
          ),
        ],
      ),
    );
  }
}
