import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../controllers/account_entry_controller.dart';

/// Moving money between accounts, or in and out with no party attached.
class AccountEntryView extends GetView<AccountEntryController> {
  const AccountEntryView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Move money',
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: 'Save',
          isLoading: controller.isSaving.value,
          onPressed: controller.save,
        ),
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => SegmentedControl<EntryType>(
                segments: [
                  for (final type in EntryType.values)
                    Segment(value: type, label: type.label),
                ],
                value: controller.type.value,
                onChanged: controller.setType,
              ),
            ),
            AppSizes.gapMd,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(
                    () => controller.needsFrom
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: AppSizes.md),
                            child: AccountField(
                              label: 'From',
                              choice: controller.from,
                              placeholder: 'Choose an account',
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Obx(
                    () => controller.needsTo
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: AppSizes.md),
                            child: AccountField(
                              label: 'To',
                              choice: controller.to,
                              placeholder: 'Choose an account',
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  AppTextField.amount(
                    label: 'Amount',
                    controller: controller.amount,
                    validator: Validators.amount,
                    textInputAction: TextInputAction.next,
                  ),
                  AppSizes.gapMd,
                  Obx(
                    () => DateField(
                      label: 'Date',
                      value: controller.date.value,
                      onChanged: controller.setDate,
                    ),
                  ),
                  AppSizes.gapMd,
                  AppTextField(
                    label: 'What was it for? (optional)',
                    controller: controller.description,
                    hint: 'Rent, electricity, bank deposit',
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
}
