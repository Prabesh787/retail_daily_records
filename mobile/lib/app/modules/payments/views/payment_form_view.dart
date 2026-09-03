import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/supplier_payment_mode.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/supplier.dart';
import '../controllers/payment_form_controller.dart';


/// The payment form.
///
/// Mode is chosen high up because it changes what the rest of the form asks
/// for: a cheque needs its number and the date written on it, a transfer needs
/// a reference, cash needs neither. Those fields appear only for the mode that
/// uses them rather than sitting greyed out.
class PaymentFormView extends GetView<PaymentFormController> {
  const PaymentFormView({super.key});

  static const List<Segment<SupplierPaymentMode>> _modes = [
    Segment(value: SupplierPaymentMode.cash, label: 'Cash'),
    Segment(value: SupplierPaymentMode.cheque, label: 'Cheque'),
    Segment(value: SupplierPaymentMode.bankTransfer, label: 'Transfer'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Record payment',
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: controller.isCheque ? 'Record cheque' : 'Record payment',
          isLoading: controller.isSaving.value,
          onPressed: controller.save,
        ),
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  ),
                  AppSizes.gapMd,
                  Obx(
                    () => _BillField(
                      bill: controller.againstBill.value,
                      enabled: controller.supplier.value != null,
                      onTap: () => _pickBill(context),
                      onClear: () => controller.setBill(null),
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it was paid',
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.inkMuted,
                    ),
                  ),
                  AppSizes.gapXs,
                  Obx(
                    () => SegmentedControl<SupplierPaymentMode>(
                      segments: _modes,
                      value: controller.mode.value,
                      onChanged: controller.setMode,
                    ),
                  ),

                  Obx(() {
                    if (controller.isCheque) return _ChequeFields(controller: controller);
                    if (controller.hasReference) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSizes.md),
                        child: AppTextField(
                          label: 'Reference number',
                          controller: controller.referenceNo,
                          textInputAction: TextInputAction.next,
                          hint: 'Bank or wallet reference',
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(
                    () => DateField(
                      label: 'Payment date',
                      value: controller.paymentDate.value,
                      onChanged: controller.setDate,
                    ),
                  ),
                  AppSizes.gapMd,
                  AppTextField(
                    label: 'Payment date (BS)',
                    controller: controller.paymentDateBs,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    hint: '2083-05-10',
                  ),
                  AppSizes.gapMd,
                  AppTextField(
                    label: 'Voucher number',
                    controller: controller.voucherNo,
                    textInputAction: TextInputAction.next,
                    hint: 'Optional, must be unique this year',
                  ),
                ],
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    label: 'Description',
                    controller: controller.description,
                    textInputAction: TextInputAction.next,
                  ),
                  AppSizes.gapMd,
                  AppTextField(
                    label: 'Remarks',
                    controller: controller.remarks,
                    maxLines: 3,
                  ),
                ],
              ),
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
      emptyMessage: 'Add them under the Suppliers tab first.',
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

/// The cheque's own number and date.
///
/// The date written on a cheque is the one that matters — it is when the money
/// can actually leave — so it is captured separately from the day the cheque
/// was handed over, and it is what the register sorts by.
class _ChequeFields extends StatelessWidget {
  const _ChequeFields({required this.controller});

  final PaymentFormController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Cheque number',
            controller: controller.chequeNo,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: (value) => Validators.required(value, 'Cheque number'),
          ),
          AppSizes.gapMd,
          Obx(
            () => DateField(
              label: 'Date on the cheque',
              value: controller.chequeDate.value,
              onChanged: controller.setChequeDate,
            ),
          ),
          AppSizes.gapSm,
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            decoration: BoxDecoration(
              color: palette.pendingSoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: palette.pending,
                ),
                AppSizes.gapSm,
                Expanded(
                  child: Text(
                    'This reduces what you owe straight away, but stays listed '
                    'as not cleared until the bank takes it.',
                    style: AppTextStyles.caption.copyWith(
                      color: palette.pending,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
