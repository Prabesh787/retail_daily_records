import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/payment_status.dart';
import '../../../data/models/supplier_payment.dart';
import '../controllers/payment_detail_controller.dart';

/// One payment.
///
/// The status is as prominent as the amount, because for a cheque the two say
/// different things: the money is committed but may not have moved.
class PaymentDetailView extends GetView<PaymentDetailController> {
  const PaymentDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final payment = controller.payment;

      return AppScreen(
        title: payment == null ? 'Payment' : payment.paymentMode.label,
        eyebrow: payment?.supplierName,
        back: true,
        onRefresh: controller.reload,
        child: _body(context, payment),
      );
    });
  }

  Widget _body(BuildContext context, SupplierPayment? payment) {
    if (controller.isLoading.value) {
      return const Column(
        children: [
          Skeleton(height: 150, radius: AppSizes.radiusCard),
          AppSizes.gapLg,
          Skeleton(height: 200, radius: AppSizes.radiusCard),
        ],
      );
    }

    final message = controller.error.value;
    if (message != null || payment == null) {
      return ErrorView(
        message: message ?? 'This payment could not be loaded.',
        onRetry: controller.reload,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountCard(payment: payment),
        AppSizes.gapMd,

        AppCard.flush(
          child: Column(
            children: [
              AppListRow(
                leading: AppAvatar(name: payment.supplierName ?? '?'),
                title: payment.supplierName ?? 'Supplier',
                subtitle: 'Open this supplier’s ledger',
                chevron: true,
                onTap: controller.openSupplier,
              ),
              if (payment.purchaseId != null) ...[
                const RowDivider(),
                AppListRow(
                  leading: IconPlate(
                    icon: Icons.receipt_long_rounded,
                    color: context.palette.brand,
                  ),
                  title: 'Bill ${payment.purchaseBillNo ?? ''}'.trim(),
                  subtitle: 'The bill this was paid against',
                  chevron: true,
                  onTap: controller.openBill,
                ),
              ],
            ],
          ),
        ),
        AppSizes.gapMd,

        DetailList(
          rows: [
            DetailRow(
              'Paid on',
              AppDateUtils.datePair(
                payment.paymentDate,
                payment.paymentDateBs,
              ),
            ),
            DetailRow('Voucher', payment.voucherNo, mono: true),
            DetailRow('Cheque number', payment.chequeNo, mono: true),
            if (payment.chequeDate case final chequeDate?)
              DetailRow(
                'Date on the cheque',
                AppDateUtils.datePair(chequeDate, payment.chequeDateBs),
              ),
            if (payment.clearedDate case final clearedDate?)
              DetailRow('Cleared on', AppDateUtils.formatDate(clearedDate)),
            DetailRow('Reference', payment.referenceNo, mono: true),
            DetailRow('Description', payment.description),
            DetailRow('Remarks', payment.remarks),
          ],
        ),
        AppSizes.gapLg,

        _Actions(controller: controller),
        AppSizes.gapXl,
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.payment});

  final SupplierPayment payment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cancelled = payment.status == PaymentStatus.cancelled;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AMOUNT PAID',
                  style: AppTextStyles.label.copyWith(
                    color: palette.inkSubtle,
                  ),
                ),
              ),
              PaymentStatusBadge(payment.status),
            ],
          ),
          Text(
            payment.amount.display(),
            style: AppTextStyles.display.copyWith(
              color: cancelled ? palette.inkSubtle : palette.moneyIn,
              // Struck through, because the figure is still on the record but
              // no longer settles anything.
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          AppSizes.gapXs,
          Text(
            _note(payment),
            style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }

  String _note(SupplierPayment payment) => switch (payment.status) {
    PaymentStatus.issued =>
      'Already counted against what you owe. The bank has not taken it yet.',
    PaymentStatus.cleared => 'The money has left the account.',
    PaymentStatus.cancelled =>
      'Cancelled. It settles nothing and is kept only for the record.',
  };
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final PaymentDetailController controller;

  @override
  Widget build(BuildContext context) {
    // Its own Obx. The caller's Obx tracks only what runs inside *its* closure,
    // and this build is not that — without one here, `isActing` would be read
    // untracked and the button would never show it was working.
    return Obx(() {
      if (!controller.canClear && !controller.canCancel) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.canClear)
            AppButton(
              label: 'Mark as cleared',
              icon: Icons.check_circle_outline_rounded,
              isLoading: controller.isActing.value,
              onPressed: controller.clear,
            ),
          if (controller.canClear && controller.canCancel) AppSizes.gapMd,
          if (controller.canCancel)
            AppButton.danger(
              label: 'Cancel payment',
              icon: Icons.block_rounded,
              onPressed: controller.cancel,
            ),
        ],
      );
    });
  }
}
