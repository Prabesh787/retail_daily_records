import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/supplier.dart';
import '../controllers/purchase_form_controller.dart';

/// The bill form.
///
/// Four things are required — supplier, amount, bill number, date — and they
/// come first, in that order, because that is the order they are read off the
/// paper. Everything optional is below the fold.
class PurchaseFormView extends GetView<PurchaseFormController> {
  const PurchaseFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppScreen(
      title: 'New purchase',
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: 'Save bill',
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
                      // What is already owed, so the bill about to be entered
                      // has context rather than landing in a vacuum.
                      subtitle: _supplierNote(controller.supplier.value),
                      avatarName: controller.supplier.value?.name,
                      error: controller.supplierError.value,
                      onTap: () => _pickSupplier(context),
                    ),
                  ),
                  AppSizes.gapMd,
                  AppTextField.amount(
                    label: 'Bill amount',
                    controller: controller.amount,
                    validator: Validators.amount,
                    textInputAction: TextInputAction.next,
                  ),
                  AppSizes.gapMd,
                  AppTextField(
                    label: 'Bill number',
                    controller: controller.billNo,
                    validator: (value) =>
                        Validators.required(value, 'Bill number'),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    hint: '4521',
                  ),
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
                      label: 'Bill date',
                      value: controller.billDate.value,
                      onChanged: controller.setDate,
                    ),
                  ),
                  AppSizes.gapMd,
                  AppTextField(
                    label: 'Bill date (BS)',
                    controller: controller.billDateBs,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    hint: '2083-05-10',
                  ),
                  AppSizes.gapXs,
                  // Filled in from the date above, and left alone once touched:
                  // what the bill says wins over what the conversion says.
                  Text(
                    'Filled in from the date above. Change it if the bill says '
                    'something different.',
                    style: AppTextStyles.caption.copyWith(
                      color: palette.inkSubtle,
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    label: 'What was bought',
                    controller: controller.description,
                    textInputAction: TextInputAction.next,
                    hint: 'Cotton shirting, assorted colours',
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
}
