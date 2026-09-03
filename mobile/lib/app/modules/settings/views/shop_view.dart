import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../controllers/shop_controller.dart';

/// The shop's details.
class ShopView extends GetView<ShopController> {
  const ShopView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppScreen(
      title: 'Shop details',
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
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    label: 'Shop name',
                    controller: controller.name,
                    validator: Validators.name,
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
                ],
              ),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Currency symbol',
                    controller: controller.currency,
                    textInputAction: TextInputAction.done,
                    hint: 'Rs.',
                  ),
                  AppSizes.gapXs,
                  Text(
                    'Shown in front of every amount in the app.',
                    style: AppTextStyles.caption.copyWith(
                      color: palette.inkSubtle,
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.gapMd,

            Text(
              'These appear on statements and anything you share. Changes are '
              'kept on this device straight away and go up the next time you '
              'sync.',
              style: AppTextStyles.caption.copyWith(color: palette.inkSubtle),
            ),
            AppSizes.gapLg,
          ],
        ),
      ),
    );
  }
}
