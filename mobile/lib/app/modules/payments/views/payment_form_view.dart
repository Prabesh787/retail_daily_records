import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/domain/pay_method.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/ledger.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/supplier.dart';
import '../controllers/payment_form_controller.dart';


/// Payment Out: money paid to a supplier, on the same layout as every other
/// money form, in red. Payment In is this screen's mirror in green.
class PaymentFormView extends GetView<PaymentFormController> {
  const PaymentFormView({super.key});

  static const List<PayMethod> _methods = [
    PayMethod.cash,
    PayMethod.bank,
    PayMethod.cheque,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppScreen(
      title: 'Payment Out',
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: controller.isCheque ? 'Record cheque' : 'Record payment',
          color: palette.moneyOut,
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
                kind: ActivityKind.paymentOut,
                amount: controller.typedAmount,
              );
            }),
            AppSizes.gapMd,

            Obx(
              () => DocHeader(
                numberLabel: 'Voucher no.',
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
                      label: 'Supplier',
                      icon: Icons.storefront_outlined,
                      placeholder: 'Select a supplier',
                      title: controller.supplier.value?.name,
                      subtitle: _supplierNote(controller.supplier.value),
                      avatarName: controller.supplier.value?.name,
                      error: controller.supplierError.value,
                      onTap: () => _pickSupplier(context),
                    ),
                  ),
                  AppSizes.gapMd,
                  AppTextField.amount(
                    label: 'Amount paid',
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
                  accountLabel: 'Paid from',
                  chequeNo: controller.chequeNo,
                  chequeDate: controller.chequeDate.value,
                  onChequeDate: controller.setChequeDate,
                  chequeAccountLabel: 'Drawn on',
                  chequeNote:
                      'This reduces what you owe straight away, but stays '
                      'listed as not cleared until the bank takes it.',
                ),
              ),
            ),
            AppSizes.gapSm,

            MoreDetails(
              children: [
                Obx(
                  () => _BillField(
                    bill: controller.againstBill.value,
                    enabled: controller.supplier.value != null,
                    onTap: () => _pickBill(context),
                    onClear: () => controller.setBill(null),
                  ),
                ),
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
                  label: 'Date as written on the voucher (BS)',
                  controller: controller.paymentDateBs,
                  keyboardType: TextInputType.datetime,
                  textInputAction: TextInputAction.next,
                  hint: '2083-05-10',
                ),
                AppTextField(
                  label: 'Description',
                  controller: controller.description,
                  textInputAction: TextInputAction.next,
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

  String? _supplierNote(Supplier? supplier) {
    final balance = supplier?.balance;
    if (balance == null) return null;

    return balance.outstanding.isPositive
        ? 'Currently owed ${balance.outstanding.display(decimals: false)}'
        : 'Settled up';
  }

  Future<void> _pickSupplier(BuildContext context) async {
    final picked = await showPickerSheet<Supplier>(
      context: context,
      title: 'Choose a supplier',
      hint: 'Name or phone',
      search: controller.searchSuppliers,
      emptyTitle: 'No suppliers match',
      emptyMessage: 'Add them under the Parties tab first.',
      itemBuilder: (supplier, select) =>
          SupplierRow(supplier: supplier, onTap: select),
    );

    if (picked != null) controller.setSupplier(picked);
  }

  Future<void> _pickBill(BuildContext context) async {
    if (controller.supplier.value == null) return;

    final picked = await showPickerSheet<Purchase>(
      context: context,
      title: 'Against which bill?',
      hint: 'Bill number',
      search: controller.searchBills,
      emptyTitle: 'No unpaid bills',
      emptyMessage:
          'Everything recorded for this supplier is settled. The payment can '
          'still be saved without a bill.',
      itemBuilder: (bill, select) => PurchaseRow(purchase: bill, onTap: select),
    );

    if (picked != null) controller.setBill(picked);
  }
}

/// Which bill the payment settles. Optional — money can go against the account
/// in general, which is how most shops actually pay.
class _BillField extends StatelessWidget {
  const _BillField({
    required this.bill,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  final Purchase? bill;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final chosen = bill;

    return PartyField(
      label: 'Against a bill (optional)',
      icon: Icons.receipt_long_outlined,
      placeholder: enabled
          ? 'Whole account'
          : 'Choose a supplier first',
      title: chosen == null ? null : 'Bill ${chosen.billNo}',
      subtitle: chosen?.dueTotal == null
          ? null
          : '${chosen!.dueTotal!.display(decimals: false)} still owed',
      enabled: enabled,
      onTap: enabled ? onTap : null,
      onClear: chosen == null ? null : onClear,
    );
  }
}
