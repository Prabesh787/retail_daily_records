/// The rows every list in this app is made of.
///
/// One row per record type, kept in one file because their job is to be
/// consistent with each other: the party's name on the first line, whatever
/// identifies the document on the second, the money on the right. A screen that
/// builds its own row inevitably puts the amount somewhere slightly different,
/// and the app stops feeling like one app.
///
/// None of them navigate. A row appears both in a list, where a tap opens the
/// record, and in a picker sheet, where a tap selects it — so the screen says
/// what a tap means rather than the row assuming.
library;

import 'package:flutter/material.dart';

import '../../../data/enums/domain_tone.dart';
import '../../../data/enums/sale_payment_mode.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/supplier_payment.dart';
import '../../constants/app_sizes.dart';
import '../../domain/money.dart';
import '../../extensions/context_ext.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/tone_colors.dart';
import '../../utils/date_utils.dart';
import '../app_badge.dart';
import '../app_card.dart';
import '../app_list_row.dart';
import 'status_badge.dart';
/// A wholesale bill.
class PurchaseRow extends StatelessWidget {
  const PurchaseRow({super.key, required this.purchase, this.onTap});

  final Purchase purchase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = purchase.supplierName ?? 'Unknown supplier';
    final billDate =
        AppDateUtils.datePair(purchase.billDate, purchase.billDateBs);

    return AppListRow(
      leading: AppAvatar(name: name),
      title: name,
      subtitle: 'Bill ${purchase.billNo} · $billDate',
      trailing: [
        RowAmount(
          purchase.amount.display(decimals: false),
          tone: MoneyTone.outbound,
        ),
      ],
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

/// One sale.
///
/// [showDate] is off inside a day group, where every row shares the date and
/// the time is the only thing that tells two sales apart.
class SaleRow extends StatelessWidget {
  const SaleRow({
    super.key,
    required this.sale,
    this.showDate = false,
    this.onTap,
  });

  final Sale sale;
  final bool showDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = sale.customerName ?? 'Walk-in customer';
    final mode = sale.payments.isEmpty ? null : sale.payments.first.paymentMode;
    final onCredit = mode == SalePaymentMode.credit;

    final when = showDate
        ? AppDateUtils.datePair(sale.saleDate, sale.saleDateBs)
        : AppDateUtils.formatTime(sale.createdAt);

    final itemCount = sale.items.length;
    final what = sale.saleType.hasItems
        ? 'Invoice ${sale.invoiceNo ?? '—'} · '
              '$itemCount item${itemCount == 1 ? '' : 's'}'
        : sale.description;

    return AppListRow(
      leading: AppAvatar(
        name: sale.customerName ?? sale.description ?? 'Walk-in',
      ),
      title: name,
      subtitle: [
        when,
        ?what,
      ].where((part) => part.isNotEmpty).join(' · '),
      trailing: [
        // Credit is amber, not green: the goods left the shop but no money came
        // in, and colouring it as takings is how a day's till stops matching
        // the day book.
        RowAmount(
          sale.totalAmount.display(decimals: false),
          tone: onCredit ? MoneyTone.pending : MoneyTone.inbound,
        ),
        if (onCredit)
          const AppBadge(label: 'Credit', tone: DomainTone.warning)
        else
          RowCaption(mode?.label ?? sale.saleType.shortLabel),
      ],
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

/// A supplier, with what is still owed on the right.
class SupplierRow extends StatelessWidget {
  const SupplierRow({super.key, required this.supplier, this.onTap});

  final Supplier supplier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final balance = supplier.balance;
    final outstanding = balance?.outstanding ?? Money.zero;
    final owes = outstanding.isPositive;

    return AppListRow(
      leading: AppAvatar(name: supplier.name),
      title: supplier.name,
      subtitle: _joinDetails(supplier.phone, supplier.address),
      trailing: [
        RowAmount(
          owes ? outstanding.display(decimals: false) : 'Settled',
          tone: owes ? MoneyTone.outbound : MoneyTone.plain,
        ),
        if (balance != null)
          RowCaption(
            '${balance.billCount} bill${balance.billCount == 1 ? '' : 's'}',
          ),
      ],
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

/// A customer, with what they have bought.
class CustomerRow extends StatelessWidget {
  const CustomerRow({super.key, required this.customer, this.onTap});

  final Customer customer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final total = customer.saleTotal;
    final count = customer.saleCount ?? 0;

    return AppListRow(
      leading: AppAvatar(name: customer.name),
      title: customer.name,
      subtitle: _joinDetails(customer.phone, customer.address),
      trailing: [
        // Both lines or neither: a list query that did not ask for the totals
        // leaves them null, and a lone "0 sales" would read as a fact rather
        // than as a figure nobody fetched.
        if (total != null) ...[
          RowAmount(total.display(decimals: false), tone: MoneyTone.inbound),
          RowCaption('$count sale${count == 1 ? '' : 's'}'),
        ],
      ],
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

/// A payment made to a supplier.
class PaymentRow extends StatelessWidget {
  const PaymentRow({
    super.key,
    required this.payment,
    this.showSupplier = true,
    this.onTap,
  });

  final SupplierPayment payment;

  /// Off on a supplier's own statement, where the name is the screen title and
  /// repeating it on every row says nothing.
  final bool showSupplier;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = payment.supplierName ?? 'Payment';
    final chequeDate = payment.chequeDate;

    final when = payment.paymentMode.isCheque && chequeDate != null
        ? 'Cheque ${payment.chequeNo ?? '—'} · '
              'dated ${AppDateUtils.relativeDay(chequeDate)}'
        : AppDateUtils.datePair(payment.paymentDate, payment.paymentDateBs);

    return AppListRow(
      leading: AppAvatar(name: name),
      title: showSupplier ? name : 'Voucher ${payment.voucherNo ?? '—'}',
      subtitle: [
        when,
        // Which bill this settles, where it settles a specific one.
        if (payment.purchaseBillNo != null) 'Bill ${payment.purchaseBillNo}',
      ].join(' · '),
      trailing: [
        RowAmount(payment.amount.display(decimals: false)),
        PaymentStatusBadge(payment.status),
      ],
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

/// A cheque in the register, with how long until it falls due.
class ChequeRow extends StatelessWidget {
  const ChequeRow({super.key, required this.payment, this.onTap});

  final SupplierPayment payment;
  final VoidCallback? onTap;

  /// The register exists to answer "what is about to hit the account", so the
  /// countdown is the point of the row and the date is the supporting detail.
  String? get _dueLabel {
    final due = payment.chequeDate;
    if (due == null) return null;
    final days = AppDateUtils.daysUntil(due);
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'due today';
    return 'in ${days}d';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = payment.supplierName ?? 'Cheque';
    final due = _dueLabel;
    final chequeDate = payment.chequeDate;

    return AppListRow(
      leading: AppAvatar(name: name),
      title: name,
      subtitle: [
        'No. ${payment.chequeNo ?? '—'}',
        if (chequeDate != null)
          AppDateUtils.datePair(chequeDate, payment.chequeDateBs),
      ].join(' · '),
      trailing: [
        RowAmount(payment.amount.display(decimals: false)),
        if (due != null)
          Text(
            due,
            style: AppTextStyles.label.copyWith(color: palette.pending),
          ),
      ],
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

/// The date separator inside a grouped list.
///
/// Carries the day's total, because that is the figure being scanned for and
/// the rows beneath it are the working. Tappable where the day has a record of
/// its own to open.
class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.label,
    this.total,
    this.count,
    this.onTap,
  });

  final String label;
  final Money? total;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dayTotal = total;

    return Material(
      color: palette.sunken,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: 7,
          ),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.label.copyWith(
                  color: palette.inkSubtle,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '· $count sale${count == 1 ? '' : 's'}',
                  style: AppTextStyles.label.copyWith(
                    color: palette.inkSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              if (dayTotal != null)
                Text(
                  dayTotal.display(decimals: false),
                  style: AppTextStyles.label.copyWith(
                    color: palette.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: palette.inkSubtle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone and address on the second line, with neither leaving a stray
/// separator behind when it is missing.
String _joinDetails(String? phone, String? address) => [
  phone,
  address,
].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
