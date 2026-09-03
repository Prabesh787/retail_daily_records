import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/enums/sale_payment_mode.dart';
import '../../../data/enums/sale_type.dart';
import '../../../data/models/customer.dart';
import '../controllers/sale_form_controller.dart';

/// The sale form.
///
/// The biggest screen in the app, and the only one with two shapes. "Total
/// only" is a day's counter takings keyed as one figure; "Itemised" is an
/// invoice with lines. The choice comes first because it decides what the rest
/// of the form asks for.
class SaleFormView extends GetView<SaleFormController> {
  const SaleFormView({super.key});

  static const List<Segment<SaleType>> _types = [
    Segment(value: SaleType.summary, label: 'Total only'),
    Segment(value: SaleType.detailed, label: 'Itemised'),
  ];

  static const List<Segment<SalePaymentMode>> _modes = [
    Segment(value: SalePaymentMode.cash, label: 'Cash'),
    Segment(value: SalePaymentMode.bank, label: 'Bank'),
    Segment(value: SalePaymentMode.cheque, label: 'Cheque'),
    Segment(value: SalePaymentMode.credit, label: 'Credit'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'New sale',
      back: true,
      // No Obx here: `_SaveBar` owns one internally. An Obx whose closure only
      // constructs a child tracks nothing — the child's `build` runs later,
      // outside the tracking scope — and GetX throws rather than silently
      // never updating.
      bottomBar: _SaveBar(controller: controller),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => SegmentedControl<SaleType>(
                segments: _types,
                value: controller.saleType.value,
                onChanged: controller.setSaleType,
              ),
            ),
            AppSizes.gapMd,

            Obx(
              () => controller.isItemised
                  ? _Lines(controller: controller)
                  : _SummaryAmount(controller: controller),
            ),
            AppSizes.gapMd,

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it was settled',
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.inkMuted,
                    ),
                  ),
                  AppSizes.gapXs,
                  Obx(
                    () => SegmentedControl<SalePaymentMode>(
                      segments: _modes,
                      value: controller.paymentMode.value,
                      onChanged: controller.setPaymentMode,
                    ),
                  ),
                  AppSizes.gapMd,

                  Obx(
                    () => PartyField(
                      label: controller.isCredit
                          ? 'Customer'
                          : 'Customer (optional)',
                      icon: Icons.person_outline_rounded,
                      placeholder: controller.isCredit
                          ? 'Who owes this?'
                          : 'Walk-in',
                      title: controller.customer.value?.name,
                      subtitle: _customerNote(controller.customer.value),
                      avatarName: controller.customer.value?.name,
                      error: controller.customerError.value,
                      onTap: () => _pickCustomer(context),
                      onClear: controller.customer.value == null
                          ? null
                          : () => controller.setCustomer(null),
                    ),
                  ),

                  // Not asked for on a credit sale: nothing is being settled,
                  // and a "paid now" box on it would invite a contradiction.
                  Obx(
                    () => controller.isCredit
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSizes.md),
                            child: AppTextField.amount(
                              label: 'Paid now',
                              controller: controller.paidAmount,
                              hint: 'Leave empty if paid in full',
                              onChanged: (_) =>
                                  controller.itemsRevision.value++,
                            ),
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
                  Obx(
                    () => DateField(
                      label: 'Sale date',
                      value: controller.saleDate.value,
                      onChanged: controller.setDate,
                    ),
                  ),
                  AppSizes.gapMd,
                  AppTextField(
                    label: 'Sale date (BS)',
                    controller: controller.saleDateBs,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                  ),
                  AppSizes.gapMd,
                  AppTextField(
                    label: 'Invoice number',
                    controller: controller.invoiceNo,
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

  /// What this customer has bought before.
  ///
  /// Not what they owe: unlike a supplier, a customer carries no derived
  /// balance in this system — receivables live on the sales themselves. Saying
  /// "owes nothing" here would be a claim the data cannot support.
  String? _customerNote(Customer? customer) {
    final count = customer?.saleCount;
    final total = customer?.saleTotal;
    if (count == null || total == null || count == 0) return null;

    return '$count sale${count == 1 ? '' : 's'} · '
        '${total.display(decimals: false)}';
  }

  Future<void> _pickCustomer(BuildContext context) async {
    final picked = await showPickerSheet<Customer>(
      context: context,
      title: 'Choose a customer',
      hint: 'Name or phone',
      search: controller.searchCustomers,
      emptyTitle: 'No customers match',
      emptyMessage: 'A counter sale does not need one — leave it as walk-in.',
      itemBuilder: (customer, select) =>
          CustomerRow(customer: customer, onTap: select),
    );

    if (picked != null) controller.setCustomer(picked);
  }
}

/// The single-figure shape: what the counter took, typed straight in.
class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({required this.controller});

  final SaleFormController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppTextField.amount(
            label: 'Sale total',
            controller: controller.summaryTotal,
            validator: Validators.amount,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onChanged: (_) => controller.itemsRevision.value++,
          ),
          AppSizes.gapMd,
          AppTextField.amount(
            label: 'Discount',
            controller: controller.discount,
            onChanged: (_) => controller.itemsRevision.value++,
          ),
        ],
      ),
    );
  }
}

/// The itemised shape.
///
/// The total is not a field here — it is the sum of the lines, shown but not
/// editable, because an invoice whose total disagrees with its own rows is the
/// single worst thing this form could produce.
class _Lines extends StatelessWidget {
  const _Lines({required this.controller});

  final SaleFormController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Obx(() {
      // Read so the totals below recompute as the line fields are typed in.
      controller.itemsRevision.value;

      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < controller.items.length; i++) ...[
              if (i > 0) ...[
                AppSizes.gapMd,
                const RowDivider(full: true),
                AppSizes.gapMd,
              ],
              _LineFields(
                index: i,
                controller: controller,
                onRemove: controller.items.length > 1
                    ? () => controller.removeItem(i)
                    : null,
              ),
            ],

            AppSizes.gapMd,
            AppOutlinedButton(
              label: 'Add line',
              icon: Icons.add_rounded,
              expanded: false,
              onPressed: controller.addItem,
            ),

            AppSizes.gapMd,
            const RowDivider(full: true),
            AppSizes.gapMd,

            AppTextField.amount(
              label: 'Discount',
              controller: controller.discount,
              onChanged: (_) => controller.itemsRevision.value++,
            ),
            AppSizes.gapMd,

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lines total',
                    style: AppTextStyles.body.copyWith(color: palette.inkMuted),
                  ),
                ),
                Text(
                  controller.itemsSubtotal.display(),
                  style: AppTextStyles.amountSmall.copyWith(color: palette.ink),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _LineFields extends StatelessWidget {
  const _LineFields({
    required this.index,
    required this.controller,
    this.onRemove,
  });

  final int index;
  final SaleFormController controller;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final draft = controller.items[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Item ${index + 1}',
                controller: draft.description,
                textInputAction: TextInputAction.next,
                hint: 'What was sold',
              ),
            ),
            if (onRemove != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSizes.xs, top: 18),
                child: IconButton(
                  tooltip: 'Remove line',
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: palette.inkSubtle,
                  ),
                  onPressed: onRemove,
                ),
              ),
          ],
        ),
        AppSizes.gapSm,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 3,
              child: AppTextField(
                label: 'Qty',
                controller: draft.quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
            AppSizes.gapSm,
            Expanded(
              flex: 3,
              child: AppTextField(
                label: 'Unit',
                controller: draft.unit,
                textInputAction: TextInputAction.next,
              ),
            ),
            AppSizes.gapSm,
            Expanded(
              flex: 4,
              child: AppTextField.amount(
                label: 'Rate',
                controller: draft.unitPrice,
              ),
            ),
          ],
        ),
        AppSizes.gapXs,
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            draft.amount.display(),
            style: AppTextStyles.amountSmall.copyWith(
              fontSize: 14,
              color: draft.isValid ? palette.ink : palette.inkSubtle,
            ),
          ),
        ),
      ],
    );
  }
}

/// The save bar, which states the total it is about to commit.
///
/// A form this long can be saved from a screen position where the total is
/// scrolled out of sight, so the figure travels with the button.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller});

  final SaleFormController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // The Obx lives here rather than around this widget at the call site,
    // because tracking only happens inside the closure that is actually
    // running — and the closure that runs is this `build`.
    return Obx(() {
      // Read so the bar tracks the line fields as they are typed.
      controller.itemsRevision.value;

      final due = controller.dueNow;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: AppTextStyles.body.copyWith(color: palette.inkMuted),
                ),
              ),
              Text(
                controller.grandTotal.display(),
                style: AppTextStyles.amount.copyWith(color: palette.ink),
              ),
            ],
          ),
          if (due.isPositive) ...[
            AppSizes.gapXs,
            Row(
              children: [
                Expanded(
                  child: Text(
                    'On credit',
                    style: AppTextStyles.caption.copyWith(
                      color: palette.pending,
                    ),
                  ),
                ),
                Text(
                  due.display(),
                  style: AppTextStyles.amountSmall.copyWith(
                    fontSize: 14,
                    color: palette.pending,
                  ),
                ),
              ],
            ),
          ],
          AppSizes.gapMd,
          AppButton(
            label: 'Save sale',
            isLoading: controller.isSaving.value,
            onPressed: controller.save,
          ),
        ],
      );
    });
  }
}
