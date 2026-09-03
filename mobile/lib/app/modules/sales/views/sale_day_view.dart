import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/sale_payment_mode.dart';
import '../../../data/repositories/sale_repository.dart';
import '../controllers/sale_day_controller.dart';

/// One day, both sides of the counter.
///
/// What came in, how it was settled, and what went out the same day. There is
/// no stored "day's takings" anywhere in this system — the figure at the top is
/// the sum of the sales listed beneath it, which is why the two can never
/// disagree.
class SaleDayView extends GetView<SaleDayController> {
  const SaleDayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final book = controller.book;

      return AppScreen(
        title: AppDateUtils.relativeDay(controller.dateMs),
        eyebrow: AppDateUtils.datePair(controller.dateMs, book?.dateBs),
        back: true,
        onRefresh: controller.reload,
        child: _body(context, book),
      );
    });
  }

  Widget _body(BuildContext context, DayBook? book) {
    if (controller.isLoading.value) {
      return const Column(
        children: [
          Skeleton(height: 170, radius: AppSizes.radiusCard),
          AppSizes.gapLg,
          Skeleton(height: 220, radius: AppSizes.radiusCard),
        ],
      );
    }

    final message = controller.error.value;
    if (message != null || book == null) {
      return ErrorView(
        message: message ?? 'This day could not be loaded.',
        onRetry: controller.reload,
      );
    }

    if (book.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Nothing on this day',
        message: 'No sales, no bills and no payments were recorded.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TakingsCard(book: book),
        AppSizes.gapLg,

        if (book.sales.isNotEmpty) ...[
          SectionHeader(title: 'SALES (${book.saleCount})'),
          AppCard.flush(
            child: Column(
              children: [
                for (var i = 0; i < book.sales.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  SaleRow(
                    sale: book.sales[i],
                    onTap: () => controller.openSale(book.sales[i]),
                  ),
                ],
              ],
            ),
          ),
          AppSizes.gapLg,
        ],

        // The other side of the day. A sales-only screen would leave the
        // shopkeeper to work out whether a good day of takings was also a day
        // they spent more than they took.
        if (book.purchases.isNotEmpty) ...[
          SectionHeader(
            title: 'BILLS TAKEN ON (${book.purchases.length})',
            action: book.purchaseTotal.display(decimals: false),
          ),
          AppCard.flush(
            child: Column(
              children: [
                for (var i = 0; i < book.purchases.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  PurchaseRow(
                    purchase: book.purchases[i],
                    onTap: () => controller.openPurchase(book.purchases[i]),
                  ),
                ],
              ],
            ),
          ),
          AppSizes.gapLg,
        ],

        if (book.payments.isNotEmpty) ...[
          SectionHeader(
            title: 'PAID OUT (${book.payments.length})',
            action: book.paymentTotal.display(decimals: false),
          ),
          AppCard.flush(
            child: Column(
              children: [
                for (var i = 0; i < book.payments.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  PaymentRow(
                    payment: book.payments[i],
                    onTap: () => controller.openPayment(book.payments[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        AppSizes.gapXl,
      ],
    );
  }
}

/// The day's headline: what was taken, and the split behind it.
class _TakingsCard extends StatelessWidget {
  const _TakingsCard({required this.book});

  final DayBook book;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final modes = book.byMode;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAKINGS',
            style: AppTextStyles.label.copyWith(color: palette.inkSubtle),
          ),
          Text(
            book.received.display(),
            style: AppTextStyles.display.copyWith(color: palette.moneyIn),
          ),
          Text(
            // Sold and taken are different figures whenever anything went out
            // on credit, and the card says both rather than picking one.
            book.onCredit.isPositive
                ? '${book.salesTotal.display(decimals: false)} sold · '
                      '${book.onCredit.display(decimals: false)} on credit'
                : '${book.saleCount} sale'
                      '${book.saleCount == 1 ? '' : 's'}, all settled',
            style: AppTextStyles.caption.copyWith(
              color: book.onCredit.isPositive
                  ? palette.pending
                  : palette.inkMuted,
            ),
          ),

          if (modes.isNotEmpty) ...[
            AppSizes.gapMd,
            const RowDivider(full: true),
            AppSizes.gapMd,
            Wrap(
              spacing: AppSizes.lg,
              runSpacing: AppSizes.sm,
              children: [
                for (final row in modes)
                  _ModeChip(mode: row.mode, amount: row.amount.display(
                    decimals: false,
                  )),
              ],
            ),
          ],

          if (book.purchaseTotal.isPositive ||
              book.paymentTotal.isPositive) ...[
            AppSizes.gapMd,
            const RowDivider(full: true),
            AppSizes.gapMd,
            Row(
              children: [
                Expanded(
                  child: _Out(
                    label: 'Bills taken on',
                    text: book.purchaseTotal.display(decimals: false),
                  ),
                ),
                Expanded(
                  child: _Out(
                    label: 'Paid to suppliers',
                    text: book.paymentTotal.display(decimals: false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.amount});

  final SalePaymentMode mode;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          mode.label,
          style: AppTextStyles.label.copyWith(
            color: palette.inkSubtle,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          amount,
          style: AppTextStyles.amountSmall.copyWith(
            fontSize: 15,
            // Credit is amber here too, for the same reason it is amber
            // everywhere else: it is a promise, not money in the till.
            color: mode.isSettled ? palette.ink : palette.pending,
          ),
        ),
      ],
    );
  }
}

class _Out extends StatelessWidget {
  const _Out({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label.copyWith(
            color: palette.inkSubtle,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          text,
          maxLines: 1,
          style: AppTextStyles.amountSmall.copyWith(
            fontSize: 15,
            color: palette.moneyOut,
          ),
        ),
      ],
    );
  }
}
