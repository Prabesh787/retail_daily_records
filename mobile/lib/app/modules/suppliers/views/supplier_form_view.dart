import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../controllers/supplier_form_controller.dart';

/// The supplier form.
///
/// Grouped into three cards — who they are, how to reach them, and what the
/// books already say — because a single column of nine fields reads as a form
/// to be endured rather than three short questions.
class SupplierFormView extends GetView<SupplierFormController> {
  const SupplierFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: controller.title,
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: controller.isEdit ? 'Save changes' : 'Add supplier',
          isLoading: controller.isSaving.value,
          onPressed: controller.save,
        ),
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSizes.xxl),
            child: LoadingView(),
          );
        }

        return Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Supplier name',
                      controller: controller.name,
                      validator: Validators.name,
                      autofocus: !controller.isEdit,
                      textInputAction: TextInputAction.next,
                      hint: 'ABC Textile Suppliers',
                    ),
                    AppSizes.gapMd,
                    AppTextField(
                      label: 'Contact person',
                      controller: controller.contactPerson,
                      textInputAction: TextInputAction.next,
                      hint: 'Who you actually speak to',
                    ),
                  ],
                ),
              ),
              AppSizes.gapMd,

              AppCard(
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Phone',
                      controller: controller.phone,
                      validator: Validators.phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.call_outlined,
                    ),
                    AppSizes.gapMd,
                    AppTextField(
                      label: 'Address',
                      controller: controller.address,
                      textInputAction: TextInputAction.next,
                      hint: 'Butwal-11, Rupandehi',
                    ),
                    AppSizes.gapMd,
                    AppTextField(
                      label: 'PAN',
                      controller: controller.pan,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                    AppSizes.gapMd,
                    AppTextField(
                      label: 'Email',
                      controller: controller.email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
              AppSizes.gapMd,

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField.amount(
                      label: 'Opening balance',
                      controller: controller.openingBalance,
                    ),
                    AppSizes.gapXs,
                    // The one field people get wrong, so it says which way it
                    // points rather than assuming.
                    Text(
                      'What you already owed them before using this app. '
                      'Leave empty if nothing.',
                      style: AppTextStyles.caption.copyWith(
                        color: context.palette.inkSubtle,
                      ),
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

              if (controller.isEdit) ...[
                AppSizes.gapMd,
                AppCard(
                  child: Obx(
                    () => SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.isActive.value,
                      onChanged: (value) => controller.isActive.value = value,
                      title: Text('Active', style: AppTextStyles.bodyStrong),
                      subtitle: Text(
                        controller.isActive.value
                            ? 'Offered when recording a bill or a payment.'
                            : 'Hidden from pickers. Existing records are kept.',
                        style: AppTextStyles.caption.copyWith(
                          color: context.palette.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                if (controller.canDelete.value) ...[
                  AppSizes.gapLg,
                  AppButton.danger(
                    label: 'Delete supplier',
                    icon: Icons.delete_outline_rounded,
                    onPressed: controller.delete,
                  ),
                ],
              ],
              AppSizes.gapLg,
            ],
          ),
        );
      }),
    );
  }
}
