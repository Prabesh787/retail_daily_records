import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/domain/calculator.dart';
import '../../../core/domain/pay_method.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/customer.dart';
import '../controllers/quick_sale_controller.dart';

/// Quick Sale: a calculator with a Record button.
///
/// Fills the screen and never scrolls, so the keypad is always under the same
/// thumb. The keypad takes whatever height is left, which is what lets it fit a
/// small phone without anything falling off the bottom.
class QuickSaleView extends GetView<QuickSaleController> {
  const QuickSaleView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppScreen(
      title: 'Quick Sale',
      back: true,
      scrollable: false,
      padded: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.xs,
          AppSizes.lg,
          AppSizes.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => SegmentedControl<PayMethod>(
                segments: [
                  for (final option in QuickSaleController.methods)
                    Segment(value: option, label: option.label),
                ],
                value: controller.method.value,
                onChanged: controller.setMethod,
              ),
            ),
            Obx(() {
              final method = controller.method.value;
              if (method.needsAccount) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSizes.sm),
                  child: AccountField(
                    label: 'Received in',
                    choice: controller.account,
                    banksOnly: true,
                  ),
                );
              }
              if (method.isCredit) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSizes.sm),
                  child: PartyField(
                    label: 'Customer',
                    icon: Icons.person_outline_rounded,
                    placeholder: 'Who owes this?',
                    title: controller.customer.value?.name,
                    avatarName: controller.customer.value?.name,
                    error: controller.customerError.value,
                    onTap: () => _pickCustomer(context),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            AppSizes.gapSm,
            Expanded(flex: 2, child: _Display(controller: controller)),
            AppSizes.gapSm,
            Obx(
              () => SizedBox(
                height: AppSizes.control,
                child: AppButton(
                  label: controller.method.value.isCredit
                      ? 'Record credit sale'
                      : 'Record sale',
                  icon: Icons.check_rounded,
                  color: palette.moneyIn,
                  isLoading: controller.isSaving.value,
                  onPressed: controller.record,
                ),
              ),
            ),
            AppSizes.gapSm,
            Expanded(flex: 5, child: _Keypad(controller: controller)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomer(BuildContext context) async {
    final picked = await showPickerSheet<Customer>(
      context: context,
      title: 'Choose a customer',
      hint: 'Name or phone',
      search: controller.searchCustomers,
      emptyTitle: 'No customers match',
      emptyMessage: 'Add them under the Parties tab first.',
      itemBuilder: (customer, select) =>
          CustomerRow(customer: customer, onTap: select),
    );

    if (picked != null) controller.setCustomer(picked);
  }
}

class _Display extends StatelessWidget {
  const _Display({required this.controller});

  final QuickSaleController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: palette.moneyInSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Obx(() {
        final last = controller.lastSale.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Text(
                    controller.expression.value,
                    maxLines: 1,
                    style: AppTextStyles.body.copyWith(color: palette.inkMuted),
                  ),
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                controller.total.value.display(),
                style: AppTextStyles.display.copyWith(
                  fontSize: 36,
                  color: palette.moneyIn,
                ),
              ),
            ),
            if (last != null)
              Text(
                'Last recorded: ${last.display(decimals: false)}',
                maxLines: 1,
                style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
              ),
          ],
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.controller});

  final QuickSaleController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = controller;

    _Key number(String value) =>
        _Key(label: value, onTap: () => c.digit(value));
    _Key op(String value) => _Key(
      label: value,
      tinted: true,
      onTap: () => c.operator_(value),
    );

    return Column(
      children: [
        _row([
          _Key(label: 'AC', tinted: true, onTap: c.clear),
          _Key(label: '%', tinted: true, onTap: c.percent),
          op(Calculator.divide),
          _Key(
            icon: Icons.backspace_outlined,
            semantics: 'Delete',
            tinted: true,
            onTap: c.backspace,
          ),
        ]),
        _row([number('7'), number('8'), number('9'), op(Calculator.times)]),
        _row([number('4'), number('5'), number('6'), op(Calculator.minus)]),
        _row([number('1'), number('2'), number('3'), op(Calculator.plus)]),
        _row([
          number('0'),
          _Key(label: '.', onTap: c.decimalPoint),
          _Key(
            label: '=',
            color: palette.moneyIn,
            foreground: Colors.white,
            flex: 2,
            onTap: c.equals,
          ),
        ]),
      ],
    );
  }

  Widget _row(List<_Key> keys) => Expanded(
    child: Row(
      children: [
        for (final key in keys)
          Expanded(
            flex: key.flex,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: key,
            ),
          ),
      ],
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({
    required this.onTap,
    this.label,
    this.icon,
    this.semantics,
    this.tinted = false,
    this.color,
    this.foreground,
    this.flex = 1,
  });

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final String? semantics;
  final bool tinted;
  final Color? color;
  final Color? foreground;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = foreground ?? palette.ink;

    return Material(
      color: color ?? (tinted ? palette.sunken : palette.surface),
      borderRadius: BorderRadius.circular(AppSizes.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: icon != null
              ? Icon(icon, size: 22, color: ink, semanticLabel: semantics)
              : Text(
                  label ?? '',
                  style: AppTextStyles.h2.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
