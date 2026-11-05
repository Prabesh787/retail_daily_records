import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/domain/pay_method.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/ledger.dart';
import '../controllers/receipt_form_controller.dart';

/// Payment In: the mirror of Payment Out, in green.
class ReceiptFormView extends GetView<ReceiptFormController> {
  const ReceiptFormView({super.key});

  static const List<PayMethod> _methods = [
    PayMethod.cash,
    PayMethod.bank,
    PayMethod.cheque,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppScreen(
      title: 'Payment In',
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: controller.isCheque ? 'Record cheque' : 'Record payment',
          color: palette.moneyIn,
          isLoading: controller.isSaving.value,
          onPressed: controller.save,
        ),
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              controller.amountRevision.value;
              return TxnBanner(
                kind: ActivityKind.paymentIn,
                amount: controller.typedAmount,
                note: controller.againstSale.value == null
                    ? null
                    : 'Against sale '
                          '${controller.againstSale.value!.invoiceNo ?? ''}',
              );
            }),
            AppSizes.gapMd,

            Obx(
              () => DocHeader(
                numberLabel: 'Receipt no.',
                number: controller.voucherNo,
                numberHint: 'Optional',
                date: controller.paymentDate.value,
                onDate: controller.setDate,
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(
                    () => PartyField(
                      label: 'Customer',
                      icon: Icons.person_outline_rounded,
                      placeholder: 'Who paid?',
                      title: controller.customer.value?.name,
                      subtitle: _note(controller.customer.value),
                      avatarName: controller.customer.value?.name,
                      error: controller.customerError.value,
                      onTap: () => _pickCustomer(context),
                    ),
                  ),
                  AppSizes.gapMd,
                  AppTextField.amount(
                    label: 'Amount received',
                    controller: controller.amount,
                    validator: Validators.amount,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => controller.amountRevision.value++,
                  ),
                ],
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Obx(
                () => PayMethodSection(
                  label: 'How was it paid?',
                  methods: _methods,
                  method: controller.method.value,
                  onChanged: controller.setMethod,
                  account: controller.account,
                  accountLabel: 'Received in',
                  chequeNo: controller.chequeNo,
                  chequeDate: controller.chequeDate.value,
                  onChequeDate: controller.setChequeDate,
                  chequeNote:
                      'Comes off what they owe now. It reaches the bank balance '
                      'once you mark it cleared under Cheques.',
                ),
              ),
            ),
            AppSizes.gapSm,

            MoreDetails(
              children: [
                Obx(
                  () => controller.hasReference
                      ? AppTextField(
                          label: 'Reference number',
                          controller: controller.referenceNo,
                          textInputAction: TextInputAction.next,
                          hint: 'Bank or wallet reference',
                        )
                      : const SizedBox.shrink(),
                ),
                AppTextField(
                  label: 'Remarks',
                  controller: controller.remarks,
                  maxLines: 3,
                ),
              ],
            ),
            AppSizes.gapLg,
          ],
        ),
      ),
    );
  }

  String? _note(Customer? customer) {
    final owed = customer?.receivable;
    if (owed == null) return null;

    return owed.isPositive
        ? 'Owes ${owed.display(decimals: false)}'
        : 'Nothing owed';
  }

  Future<void> _pickCustomer(BuildContext context) async {
    final picked = await showPickerSheet<Customer>(
      context: context,
      title: 'Choose a customer',
      hint: 'Name or phone',
      search: controller.searchCustomers,
      emptyTitle: 'No customers match',
      emptyMessage: 'Add them under the Parties tab first.',
      itemBuilder: (customer, select) =>
          CustomerRow(customer: customer, onTap: select),
    );

    if (picked != null) controller.setCustomer(picked);
  }
}
