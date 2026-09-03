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
                    () => _SupplierField(
                      supplier: controller.supplier.value,
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

/// The supplier slot.
///
/// Not a form field, so it carries its own error line rather than borrowing a
/// `TextFormField`'s — and it shows what is owed once chosen, which is the
/// context that decides whether this bill is a surprise.
class _SupplierField extends StatelessWidget {
  const _SupplierField({
    required this.supplier,
    required this.error,
    required this.onTap,
  });

  final Supplier? supplier;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final invalid = error != null;
    final chosen = supplier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplier',
          style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
        ),
        AppSizes.gapXs,
        Material(
          color: palette.sunken,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSizes.control),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: invalid ? palette.moneyOut : palette.line,
                  width: invalid ? 1.6 : 1,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radius),
              ),
              child: Row(
                children: [
                  if (chosen != null)
                    AppAvatar(name: chosen.name, size: 34)
                  else
                    Icon(
                      Icons.storefront_outlined,
                      size: 20,
                      color: palette.inkSubtle,
                    ),
                  AppSizes.gapMd,
                  Expanded(
                    child: chosen == null
                        ? Text(
                            'Select a supplier',
                            style: AppTextStyles.body.copyWith(
                              color: palette.inkSubtle,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chosen.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: palette.ink,
                                ),
                              ),
                              if (chosen.balance case final balance?)
                                Text(
                                  balance.outstanding.isPositive
                                      ? 'Currently owed '
                                            '${balance.outstanding.display(decimals: false)}'
                                      : 'Settled up',
                                  style: AppTextStyles.caption.copyWith(
                                    color: balance.outstanding.isPositive
                                        ? palette.moneyOut
                                        : palette.inkSubtle,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: palette.inkSubtle,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (invalid)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: AppSizes.xs),
            child: Text(
              error!,
              style: AppTextStyles.caption.copyWith(color: palette.moneyOut),
            ),
          ),
      ],
    );
  }
}
