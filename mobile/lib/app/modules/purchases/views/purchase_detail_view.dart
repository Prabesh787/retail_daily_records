import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/purchase.dart';
import '../controllers/purchase_detail_controller.dart';

/// One bill.
///
/// The amount is the headline; how much of it is still owed is the second thing
/// anyone wants to know, so the two sit together rather than the second being
/// buried in the detail list.
class PurchaseDetailView extends GetView<PurchaseDetailController> {
  const PurchaseDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bill = controller.bill;

      return AppScreen(
        title: bill == null ? 'Bill' : 'Bill ${bill.billNo}',
        eyebrow: bill?.supplierName,
        back: true,
        onRefresh: controller.reload,
        child: _body(context, bill),
      );
    });
  }

  Widget _body(BuildContext context, Purchase? bill) {
    if (controller.isLoading.value) {
      return const Column(
        children: [
          Skeleton(height: 140, radius: AppSizes.radiusCard),
          AppSizes.gapLg,
          Skeleton(height: 200, radius: AppSizes.radiusCard),
        ],
      );
    }

    final message = controller.error.value;
    if (message != null || bill == null) {
      return ErrorView(
        message: message ?? 'This bill could not be loaded.',
        onRetry: controller.reload,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountCard(bill: bill),
        AppSizes.gapMd,

        AppCard.flush(
          child: AppListRow(
            leading: AppAvatar(name: bill.supplierName ?? '?'),
            title: bill.supplierName ?? 'Supplier',
            subtitle: 'Open this supplier’s ledger',
            chevron: true,
            onTap: controller.openSupplier,
          ),
        ),
        AppSizes.gapMd,

        DetailList(
          rows: [
            DetailRow('Bill number', bill.billNo, mono: true),
            DetailRow(
              'Bill date',
              AppDateUtils.datePair(bill.billDate, bill.billDateBs),
            ),
            DetailRow('Goods', bill.description),
            DetailRow('Remarks', bill.remarks),
          ],
        ),
        AppSizes.gapLg,

        _Payments(controller: controller),
        AppSizes.gapLg,

        AppButton(
          label: 'Record payment',
          icon: Icons.payments_outlined,
          onPressed: controller.recordPayment,
        ),
        AppSizes.gapXl,
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.bill});

  final Purchase bill;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final paid = bill.paidTotal;
    final due = bill.dueTotal;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BILL AMOUNT',
            style: AppTextStyles.label.copyWith(color: palette.inkSubtle),
          ),
          Text(
            bill.amount.display(),
            style: AppTextStyles.display.copyWith(color: palette.ink),
          ),

          // Only where the query actually fetched the payment totals. A bill
          // read without them should say nothing rather than imply zero paid.
          if (paid != null && due != null) ...[
            AppSizes.gapMd,
            const RowDivider(full: true),
            AppSizes.gapMd,
            Row(
              children: [
                _Figure(
                  label: 'Paid',
                  text: paid.display(decimals: false),
                  tone: MoneyTone.inbound,
                ),
                _Figure(
                  label: 'Still owed',
                  text: due.isPositive
                      ? due.display(decimals: false)
                      : 'Settled',
                  tone: due.isPositive
                      ? MoneyTone.outbound
                      : MoneyTone.inbound,
                ),
              ],
            ),
          ],
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

    return Expanded(
      child: Column(
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
      ),
    );
  }
}

class _Payments extends StatelessWidget {
  const _Payments({required this.controller});

  final PurchaseDetailController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final payments = controller.payments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'PAYMENTS (${payments.length})'),
        AppCard.flush(
          child: payments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Text(
                    'Nothing paid against this bill — it is open credit in '
                    'full.',
                    style: AppTextStyles.body.copyWith(
                      color: palette.inkMuted,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < payments.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      PaymentRow(
                        payment: payments[i],
                        showSupplier: false,
                        onTap: () => controller.openPayment(payments[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
