import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../controllers/customer_form_controller.dart';

/// The customer form, which is also the customer's page.
class CustomerFormView extends GetView<CustomerFormController> {
  const CustomerFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: controller.title,
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: controller.isEdit ? 'Save changes' : 'Add customer',
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
              // What this customer has bought, when there is a history to show.
              // It is the only figure a customer carries, and it is what makes
              // the difference between a regular and a one-off legible.
              if (controller.existing?.saleCount case final count?
                  when count > 0) ...[
                StatTile(
                  icon: Icons.receipt_rounded,
                  label: 'BOUGHT SO FAR',
                  value:
                      controller.existing!.saleTotal?.display(decimals: false) ??
                          '—',
                  foot: '$count sale${count == 1 ? '' : 's'}',
                ),
                AppSizes.gapMd,
              ],

              AppCard(
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Customer name',
                      controller: controller.name,
                      validator: Validators.name,
                      autofocus: !controller.isEdit,
                      textInputAction: TextInputAction.next,
                    ),
                    AppSizes.gapMd,
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
                      label: 'Remarks',
                      controller: controller.remarks,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),

              if (controller.isEdit) ...[
                AppSizes.gapLg,
                if (controller.canDelete.value)
                  AppButton.danger(
                    label: 'Delete customer',
                    icon: Icons.delete_outline_rounded,
                    onPressed: controller.delete,
                  )
                else
                  Text(
                    'This customer has invoices recorded, so they cannot be '
                    'deleted — their sales would be left without anyone '
                    'attached.',
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.inkSubtle,
                    ),
                  ),
              ],
              AppSizes.gapLg,
            ],
          ),
        );
      }),
    );
  }
}
