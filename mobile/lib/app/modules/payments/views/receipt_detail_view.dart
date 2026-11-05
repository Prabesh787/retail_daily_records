import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/payment_status.dart';
import '../../../data/models/customer_payment.dart';
import '../controllers/receipt_detail_controller.dart';

/// One Payment In.
class ReceiptDetailView extends GetView<ReceiptDetailController> {
  const ReceiptDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final payment = controller.payment;

      return AppScreen(
        title: 'Payment In',
        eyebrow: payment?.customerName,
        back: true,
        onRefresh: controller.reload,
        child: _body(context, payment),
      );
    });
  }

  Widget _body(BuildContext context, CustomerPayment? payment) {
    if (controller.isLoading.value) {
      return const Skeleton(height: 150, radius: AppSizes.radiusCard);
    }

    final message = controller.error.value;
    if (message != null || payment == null) {
      return ErrorView(
        message: message ?? 'This payment could not be loaded.',
        onRetry: controller.reload,
      );
    }

    final palette = context.palette;
    final cancelled = payment.status == PaymentStatus.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AMOUNT RECEIVED',
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
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
              AppSizes.gapXs,
              Text(
                switch (payment.status) {
                  PaymentStatus.issued =>
                    'Taken off what they owe. Not in the bank until it clears.',
                  PaymentStatus.cleared => 'The money has reached the account.',
                  PaymentStatus.cancelled =>
                    'Cancelled. It settles nothing and is kept for the record.',
                },
                style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
              ),
            ],
          ),
        ),
        AppSizes.gapMd,

        DetailList(
          rows: [
            DetailRow('Customer', payment.customerName),
            DetailRow('Method', payment.paymentMode.label),
            DetailRow('Account', payment.accountName),
            DetailRow(
              'Received on',
              AppDateUtils.datePair(payment.paymentDate, payment.paymentDateBs),
            ),
            DetailRow('Against invoice', payment.saleInvoiceNo, mono: true),
            DetailRow('Receipt', payment.voucherNo, mono: true),
            DetailRow('Cheque number', payment.chequeNo, mono: true),
            if (payment.chequeDate case final chequeDate?)
              DetailRow(
                'Date on the cheque',
                AppDateUtils.datePair(chequeDate, payment.chequeDateBs),
              ),
            if (payment.clearedDate case final clearedDate?)
              DetailRow('Cleared on', AppDateUtils.formatDate(clearedDate)),
            DetailRow('Reference', payment.referenceNo, mono: true),
            DetailRow('Remarks', payment.remarks),
          ],
        ),
        AppSizes.gapLg,

        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.canClear) ...[
                AppButton(
                  label: 'Mark as cleared',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: controller.isActing.value,
                  onPressed: () => controller.clear(context),
                ),
                AppSizes.gapMd,
              ],
              if (controller.canCancel)
                AppButton.danger(
                  label: 'Cancel payment',
                  icon: Icons.block_rounded,
                  onPressed: controller.cancel,
                ),
            ],
          ),
        ),
        AppSizes.gapXl,
      ],
    );
  }
}
