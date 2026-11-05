import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/domain/pay_method.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/ledger.dart';
import '../../../data/models/supplier.dart';
import '../controllers/purchase_form_controller.dart';

/// The bill form: the sale form's layout, in red.
///
/// A shopkeeper who has learned one has learned both. The differences are the
/// ones paper bills force: a bill has a number, a supplier is always known, and
/// most arrive on credit.
class PurchaseFormView extends GetView<PurchaseFormController> {
  const PurchaseFormView({super.key});

  static const List<PayMethod> _methods = [
    PayMethod.credit,
    PayMethod.cash,
    PayMethod.bank,
    PayMethod.cheque,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppScreen(
      title: 'New purchase',
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: 'Save bill',
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
                kind: ActivityKind.purchase,
                amount: controller.billAmount,
              );
            }),
            AppSizes.gapMd,

            Obx(
              () => DocHeader(
                numberLabel: 'Bill no.',
                number: controller.billNo,
                numberHint: '4521',
                numberValidator: (value) =>
                    Validators.required(value, 'Bill number'),
                date: controller.billDate.value,
                onDate: controller.setDate,
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: AppTextField.amount(
                label: 'Total amount',
                controller: controller.amount,
                validator: Validators.amount,
                textInputAction: TextInputAction.next,
                onChanged: (_) => controller.amountRevision.value++,
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(
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
                          'Listed under Cheques until the bank takes it, and '
                          'taken off the balance only then.',
                    ),
                  ),
                  AppSizes.gapMd,
                  Obx(
                    () => PartyField(
                      label: 'Supplier',
                      icon: Icons.storefront_outlined,
                      placeholder: 'Select a supplier',
                      title: controller.supplier.value?.name,
                      // What is already owed, so the bill about to be entered
                      // has context rather than landing in a vacuum.
                      subtitle: _supplierNote(controller.supplier.value),
                      avatarName: controller.supplier.value?.name,
                      error: controller.supplierError.value,
                      onTap: () => _pickSupplier(context),
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.gapSm,

            MoreDetails(
              children: [
                Obx(
                  () => controller.method.value.isCredit
                      ? const SizedBox.shrink()
                      : AppTextField.amount(
                          label: 'Paid now, if only part',
                          controller: controller.paidAmount,
                          hint: 'Leave empty if paid in full',
                        ),
                ),
                // Filled in from the date above, and left alone once touched:
                // what the bill says wins over what the conversion says.
                AppTextField(
                  label: 'Date as written on the bill (BS)',
                  controller: controller.billDateBs,
                  keyboardType: TextInputType.datetime,
                  textInputAction: TextInputAction.next,
                  hint: '2083-05-10',
                ),
                AppTextField(
                  label: 'What was bought',
                  controller: controller.description,
                  textInputAction: TextInputAction.next,
                  hint: 'Cotton shirting, assorted colours',
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
}
