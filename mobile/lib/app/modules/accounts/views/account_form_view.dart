import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/account_type.dart';
import '../controllers/account_form_controller.dart';

class AccountFormView extends GetView<AccountFormController> {
  const AccountFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: controller.title,
      back: true,
      bottomBar: Obx(
        () => AppButton(
          label: controller.isEdit ? 'Save changes' : 'Add account',
          isLoading: controller.isSaving.value,
          onPressed: controller.save,
        ),
      ),
      child: Obx(() {
        if (controller.isLoading.value) return const LoadingView();

        final palette = context.palette;

        return Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!controller.isCash) ...[
                SegmentedControl<AccountType>(
                  segments: const [
                    Segment(value: AccountType.bank, label: 'Bank'),
                    Segment(value: AccountType.wallet, label: 'Wallet / QR'),
                  ],
                  value: controller.type.value,
                  onChanged: controller.setType,
                ),
                AppSizes.gapMd,
              ],
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Name',
                      controller: controller.name,
                      hint: 'Nabil Bank, eSewa',
                      validator: Validators.name,
                      autofocus: !controller.isEdit,
                      textInputAction: TextInputAction.next,
                    ),
                    if (!controller.isCash) ...[
                      AppSizes.gapMd,
                      AppTextField(
                        label: 'Account or wallet number (optional)',
                        controller: controller.accountNo,
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                    AppSizes.gapMd,
                    AppTextField.amount(
                      label: 'Balance when you started using the app',
                      controller: controller.opening,
                    ),
                    AppSizes.gapXs,
                    Text(
                      'Only for what was already there. Everything after this '
                      'is added up from your records.',
                      style: AppTextStyles.caption.copyWith(
                        color: palette.inkSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.isEdit && !controller.isCash) ...[
                AppSizes.gapMd,
                AppCard.flush(
                  child: SwitchListTile(
                    title: Text(
                      'Offer this account on forms',
                      style: AppTextStyles.body.copyWith(color: palette.ink),
                    ),
                    subtitle: Text(
                      'Turn off for a closed account. Its history stays.',
                      style: AppTextStyles.caption.copyWith(
                        color: palette.inkMuted,
                      ),
                    ),
                    value: controller.isActive.value,
                    onChanged: (value) => controller.isActive.value = value,
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
