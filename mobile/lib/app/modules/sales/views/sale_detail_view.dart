import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/sale_item.dart';
import '../../../data/models/sale_payment.dart';
import '../controllers/sale_detail_controller.dart';

/// One sale.
///
/// Total, then what was actually taken against it, then the lines. A sale on
/// credit shows the same total as a cash one and a very different second line,
/// which is the distinction the whole screen exists to make legible.
class SaleDetailView extends GetView<SaleDetailController> {
  const SaleDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sale = controller.sale;

      return AppScreen(
        title: sale?.invoiceNo == null
            ? 'Sale'
            : 'Invoice ${sale!.invoiceNo}',
        eyebrow: sale?.customerName,
        back: true,
        onRefresh: controller.reload,
        actions: [
          if (sale != null)
            IconButton(
              tooltip: 'Delete sale',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: controller.delete,
            ),
        ],
        child: _body(context, sale),
      );
    });
  }

  Widget _body(BuildContext context, Sale? sale) {
    if (controller.isLoading.value) {
      return const Column(
        children: [
          Skeleton(height: 150, radius: AppSizes.radiusCard),
          AppSizes.gapLg,
          Skeleton(height: 220, radius: AppSizes.radiusCard),
        ],
      );
    }

    final message = controller.error.value;
    if (message != null || sale == null) {
      return ErrorView(
        message: message ?? 'This sale could not be loaded.',
        onRetry: controller.reload,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TotalCard(sale: sale),
        AppSizes.gapMd,

        AppCard.flush(
          child: AppListRow(
            leading: IconPlate(
              icon: Icons.today_rounded,
              color: context.palette.brand,
            ),
            title: AppDateUtils.relativeDay(sale.saleDate),
            subtitle: 'Open the whole day’s book',
            chevron: true,
            onTap: controller.openDay,
          ),
        ),
        AppSizes.gapMd,

        if (sale.items.isNotEmpty) ...[
          SectionHeader(title: 'ITEMS (${sale.items.length})'),
          AppCard.flush(
            child: Column(
              children: [
                for (var i = 0; i < sale.items.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  _ItemRow(item: sale.items[i]),
                ],
              ],
            ),
          ),
          AppSizes.gapMd,
        ],

        if (sale.payments.isNotEmpty) ...[
          const SectionHeader(title: 'SETTLEMENT'),
          AppCard.flush(
            child: Column(
              children: [
                for (var i = 0; i < sale.payments.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  _SettlementRow(payment: sale.payments[i]),
                ],
              ],
            ),
          ),
          AppSizes.gapMd,
        ],

        DetailList(
          rows: [
            DetailRow('Invoice', sale.invoiceNo, mono: true),
            DetailRow(
              'Sale date',
              AppDateUtils.datePair(sale.saleDate, sale.saleDateBs),
            ),
            DetailRow('Customer', sale.customerName ?? 'Walk-in'),
            DetailRow('Kind', sale.saleType.label),
            DetailRow('Subtotal', sale.subtotal.display(), mono: true),
            if (sale.discount.isPositive)
              DetailRow('Discount', sale.discount.display(), mono: true),
            DetailRow('Description', sale.description),
            DetailRow('Remarks', sale.remarks),
          ],
        ),
        AppSizes.gapXl,
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final due = sale.dueTotal;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SALE TOTAL',
                  style: AppTextStyles.label.copyWith(
                    color: palette.inkSubtle,
                  ),
                ),
              ),
              SaleTypeBadge(sale.saleType),
            ],
          ),
          Text(
            sale.totalAmount.display(),
            style: AppTextStyles.display.copyWith(color: palette.ink),
          ),

          AppSizes.gapMd,
          const RowDivider(full: true),
          AppSizes.gapMd,

          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Taken',
                  text: sale.settledTotal.display(decimals: false),
                  tone: MoneyTone.inbound,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Still owed',
                  text: due.isPositive
                      ? due.display(decimals: false)
                      : 'Nothing',
                  tone: due.isPositive
                      ? MoneyTone.pending
                      : MoneyTone.inbound,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.text,
    required this.tone,
  });

  final String label;
  final String text;
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
        Text(
          text,
          maxLines: 1,
          style: AppTextStyles.amountSmall.copyWith(
            fontSize: 15,
            color: tone.ink(palette),
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: AppTextStyles.bodyStrong.copyWith(color: palette.ink),
                ),
                Text(
                  // The working behind the line amount on the right, so it can
                  // be checked without opening anything.
                  '${item.quantity.display()} ${item.unit} × '
                  '${item.unitPrice.display(decimals: false)}',
                  style: AppTextStyles.caption.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          AppSizes.gapMd,
          Text(
            item.amount.display(),
            style: AppTextStyles.amountSmall.copyWith(color: palette.ink),
          ),
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({required this.payment});

  final SalePayment payment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settled = payment.paymentMode.isSettled;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      payment.paymentMode.label,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: palette.ink,
                      ),
                    ),
                    if (payment.paymentMode.isCheque) ...[
                      const SizedBox(width: 6),
                      PaymentStatusBadge(payment.status),
                    ],
                  ],
                ),
                if (payment.chequeNo != null || payment.referenceNo != null)
                  Text(
                    payment.chequeNo != null
                        ? 'Cheque ${payment.chequeNo}'
                        : 'Ref ${payment.referenceNo}',
                    style: AppTextStyles.caption.copyWith(
                      color: palette.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            payment.amount.display(),
            style: AppTextStyles.amountSmall.copyWith(
              // Credit is amber, not green. It is a promise, and colouring it
              // as takings is how a day's till stops matching the day book.
              color: settled ? palette.moneyIn : palette.pending,
            ),
          ),
        ],
      ),
    );
  }
}
