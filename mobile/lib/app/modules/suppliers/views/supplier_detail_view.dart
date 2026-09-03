import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/domain/money.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/providers/local/supplier_dao.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../controllers/supplier_detail_controller.dart';

/// One supplier's page.
///
/// A supplier's outstanding is never read from a column — it is opening balance
/// plus bills minus payments, recomputed on every read. The ledger below shows
/// that same arithmetic as a column of movements, so the figure on the card can
/// be checked by eye rather than taken on trust.
class SupplierDetailView extends GetView<SupplierDetailController> {
  const SupplierDetailView({super.key});

  static const List<Segment<LedgerTab>> _tabs = [
    Segment(value: LedgerTab.ledger, label: 'Ledger'),
    Segment(value: LedgerTab.bills, label: 'Bills'),
    Segment(value: LedgerTab.payments, label: 'Payments'),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final statement = controller.statement;

      return AppScreen(
        title: statement?.supplier.name ?? 'Supplier',
        eyebrow: statement?.supplier.contactPerson,
        back: true,
        onRefresh: controller.reload,
        actions: [
          if (statement != null)
            IconButton(
              tooltip: 'Edit supplier',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: controller.edit,
            ),
        ],
        child: _body(context, statement),
      );
    });
  }

  Widget _body(BuildContext context, SupplierStatement? statement) {
    if (controller.isLoading.value) {
      return const Column(
        children: [
          Skeleton(height: 150, radius: AppSizes.radiusCard),
          AppSizes.gapLg,
          Skeleton(height: 220, radius: AppSizes.radiusCard),
        ],
      );
    }

    final message = controller.error.value;
    if (message != null || statement == null) {
      return ErrorView(
        message: message ?? 'This supplier could not be loaded.',
        onRetry: controller.reload,
      );
    }

    final balance = statement.supplier.balance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BalanceCard(
          amount: balance?.outstanding ?? Money.zero,
          cleared: balance?.clearedTotal,
          uncleared: balance?.uncleared,
          caption: balance == null
              ? null
              : '${balance.billCount} bill${balance.billCount == 1 ? '' : 's'} · '
                    '${balance.paymentCount} payment'
                    '${balance.paymentCount == 1 ? '' : 's'}',
        ),
        AppSizes.gapLg,

        Row(
          children: [
            Expanded(
              child: AppOutlinedButton(
                label: 'Statement',
                icon: Icons.description_outlined,
                onPressed: controller.openStatement,
              ),
            ),
            AppSizes.gapMd,
            Expanded(
              child: AppButton(
                label: 'Record payment',
                icon: Icons.payments_outlined,
                onPressed: controller.recordPayment,
              ),
            ),
          ],
        ),
        AppSizes.gapLg,

        SearchField(
          hint: 'Bill, voucher or cheque no.',
          onChanged: (value) => controller.search.value = value,
        ),
        AppSizes.gapSm,
        Align(
          alignment: Alignment.centerLeft,
          child: DateRangeChip(
            range: controller.range.value,
            onTap: () => _pickRange(context),
          ),
        ),

        // Only worth showing once something is actually narrowed — unfiltered,
        // these figures just restate the card above.
        if (controller.isFiltered) ...[
          AppSizes.gapLg,
          _WindowCard(window: statement.window),
        ],

        AppSizes.gapLg,
        SegmentedControl<LedgerTab>(
          segments: _tabs,
          value: controller.tab.value,
          onChanged: controller.setTab,
        ),
        AppSizes.gapMd,

        _rows(statement),
        AppSizes.gapLg,

        DetailList(
          rows: [
            DetailRow('Contact', statement.supplier.contactPerson),
            DetailRow('Phone', statement.supplier.phone, mono: true),
            DetailRow('Address', statement.supplier.address),
            DetailRow('PAN', statement.supplier.pan, mono: true),
            DetailRow(
              'Opening balance',
              statement.supplier.openingBalance.display(),
              mono: true,
            ),
            DetailRow(
              'Total billed',
              balance?.purchaseTotal.display(),
              mono: true,
            ),
            DetailRow('Remarks', statement.supplier.remarks),
          ],
        ),
        AppSizes.gapXl,
      ],
    );
  }

  Widget _rows(SupplierStatement statement) {
    final rows = controller.visibleRows;

    if (rows.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: controller.isFiltered
              ? 'Nothing in this range'
              : 'No records yet',
          message: controller.isFiltered
              ? 'Widen the dates, or clear the search.'
              : 'Bills and payments against this supplier will appear here.',
          actionLabel: controller.isFiltered ? 'Clear filters' : null,
          onAction: controller.clearFilters,
        ),
      );
    }

    return AppCard.flush(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const RowDivider(),
            // The same rows every other list uses. A ledger that renders its
            // own version of a bill is a third place for the format to drift.
            if (rows[i].purchase case final purchase?)
              PurchaseRow(
                purchase: purchase,
                onTap: () => controller.openBill(purchase.id),
              )
            else if (rows[i].payment case final payment?)
              PaymentRow(
                payment: payment,
                showSupplier: false,
                onTap: () => controller.openPayment(payment.id),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangeSheet(
      context: context,
      selected: controller.range.value,
    );
    if (picked != null) controller.setRange(picked);
  }
}

/// What the books did inside the chosen window, when one is chosen.
class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.window});

  final SupplierWindow window;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'IN THIS RANGE',
                  style: AppTextStyles.label.copyWith(color: palette.inkSubtle),
                ),
              ),
              Text(
                '${window.billCount} bills · ${window.paymentCount} payments',
                style: AppTextStyles.label.copyWith(
                  color: palette.inkSubtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          AppSizes.gapSm,
          Row(
            children: [
              _Figure(label: 'Opened at', amount: window.openingAsOf),
              _Figure(
                label: 'Billed',
                amount: window.purchaseTotal,
                tone: MoneyTone.outbound,
              ),
              _Figure(
                label: 'Paid',
                amount: window.paymentTotal,
                tone: MoneyTone.inbound,
              ),
            ],
          ),
          AppSizes.gapMd,
          const RowDivider(full: true),
          AppSizes.gapMd,
          Row(
            children: [
              Expanded(
                child: Text(
                  'Closing',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ),
              Text(
                window.closing.display(),
                style: AppTextStyles.amount.copyWith(color: palette.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    this.tone = MoneyTone.plain,
  });

  final String label;
  final Money amount;
  final MoneyTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(
              color: palette.inkSubtle,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            amount.display(decimals: false),
            maxLines: 1,
            style: AppTextStyles.amountSmall.copyWith(
              fontSize: 15,
              color: tone.ink(palette),
            ),
          ),
        ],
      ),
    );
  }
}
