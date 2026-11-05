/// The pieces the sale, purchase, Payment In and Payment Out forms are built
/// from, so all four read as one screen in a different colour.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/ledger.dart';
import '../../../data/models/money_account.dart';
import '../../../routes/app_pages.dart';
import '../../constants/app_sizes.dart';
import '../../controllers/account_choice.dart';
import '../../domain/money.dart';
import '../../domain/pay_method.dart';
import '../../extensions/context_ext.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_utils.dart';
import '../app_card.dart';
import '../app_list_row.dart';
import '../app_text_field.dart';
import '../date_field.dart';
import '../party_field.dart';
import '../picker_sheet.dart';
import '../segmented_control.dart';

/// The one colour rule in the app: green is money coming in, red is money going
/// out. Sale and Payment In share a colour for that reason, and are told apart
/// by their icon and their name.
extension ActivityKindStyle on ActivityKind {
  Color color(AppPalette palette) =>
      isMoneyIn ? palette.moneyIn : palette.moneyOut;

  Color soft(AppPalette palette) =>
      isMoneyIn ? palette.moneyInSoft : palette.moneyOutSoft;

  IconData get icon => switch (this) {
    ActivityKind.sale => Icons.sell_rounded,
    ActivityKind.purchase => Icons.shopping_cart_rounded,
    ActivityKind.paymentIn => Icons.south_west_rounded,
    ActivityKind.paymentOut => Icons.north_east_rounded,
  };
}

/// The strip at the top of a form: what this is and what it comes to.
///
/// The colour is the point. A shopkeeper can tell a sale from a purchase before
/// reading a word, which is what keeps money from being entered on the wrong
/// side.
class TxnBanner extends StatelessWidget {
  const TxnBanner({
    super.key,
    required this.kind,
    required this.amount,
    this.note,
  });

  final ActivityKind kind;
  final Money amount;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = kind.color(palette);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      decoration: BoxDecoration(
        color: kind.soft(palette),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Icon(kind.icon, size: 22, color: color),
          AppSizes.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.isMoneyIn ? 'Money coming in' : 'Money going out',
                  style: AppTextStyles.label.copyWith(color: color),
                ),
                if (note != null)
                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: palette.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          AppSizes.gapMd,
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount.display(),
                style: AppTextStyles.h2.copyWith(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How the money changed hands, plus whatever that choice needs: which bank for
/// Bank, the number and date for a cheque.
class PayMethodSection extends StatelessWidget {
  const PayMethodSection({
    super.key,
    required this.label,
    required this.methods,
    required this.method,
    required this.onChanged,
    required this.account,
    required this.accountLabel,
    this.chequeNo,
    this.chequeDate,
    this.onChequeDate,
    this.chequeNote,
    this.chequeAccountLabel,
  });

  final String label;
  final List<PayMethod> methods;
  final PayMethod method;
  final ValueChanged<PayMethod> onChanged;

  final AccountChoice account;

  /// Asked when [method] is Bank: "Received in" or "Paid from".
  final String accountLabel;

  final TextEditingController? chequeNo;
  final int? chequeDate;
  final ValueChanged<int>? onChequeDate;

  /// What this cheque does and does not do yet, said once at the point of entry.
  final String? chequeNote;

  /// Set when the bank is known at the time the cheque is written, as it is for
  /// a cheque the shop writes and is not for one it receives.
  final String? chequeAccountLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
        ),
        AppSizes.gapXs,
        SegmentedControl<PayMethod>(
          segments: [
            for (final option in methods)
              Segment(value: option, label: option.label),
          ],
          value: method,
          onChanged: onChanged,
        ),
        if (method.needsAccount) ...[
          AppSizes.gapMd,
          AccountField(label: accountLabel, choice: account, banksOnly: true),
        ],
        if (method.isCheque && chequeNo != null) ...[
          AppSizes.gapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Cheque number',
                  controller: chequeNo,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter the number'
                      : null,
                ),
              ),
            ],
          ),
          AppSizes.gapMd,
          DateField(
            label: 'Date on the cheque',
            value: chequeDate ?? AppDateUtils.startOfTodayMs(),
            onChanged: onChequeDate ?? (_) {},
          ),
          if (chequeAccountLabel != null) ...[
            AppSizes.gapMd,
            AccountField(
              label: chequeAccountLabel!,
              choice: account,
              banksOnly: true,
              placeholder: 'Choose a bank (optional)',
            ),
          ],
          if (chequeNote != null) ...[
            AppSizes.gapSm,
            Text(
              chequeNote!,
              style: AppTextStyles.caption.copyWith(color: palette.pending),
            ),
          ],
        ],
      ],
    );
  }
}

/// Which bank, wallet or till. Tapping with nothing set up yet goes straight to
/// adding one, because an empty picker would be a dead end mid-sale.
class AccountField extends StatelessWidget {
  const AccountField({
    super.key,
    required this.label,
    required this.choice,
    this.banksOnly = false,
    this.placeholder = 'Choose a bank or wallet',
  });

  final String label;
  final AccountChoice choice;
  final bool banksOnly;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final picked = choice.selected.value;

      return PartyField(
        label: label,
        icon: Icons.account_balance_outlined,
        placeholder: placeholder,
        title: picked?.name,
        subtitle: picked?.accountNo,
        error: choice.error.value,
        onTap: () async {
          final account = await pickAccount(context, banksOnly: banksOnly);
          if (account != null) choice.set(account);
        },
      );
    });
  }
}

/// Picks an account, or opens the form to add the first one.
Future<MoneyAccount?> pickAccount(
  BuildContext context, {
  bool banksOnly = false,
  String title = 'Choose an account',
}) async {
  final search = banksOnly ? AccountChoice.searchBanks : AccountChoice.searchAll;

  if ((await search('')).isEmpty) {
    final created = await Get.toNamed<dynamic>(Routes.accountForm);
    return created is MoneyAccount ? created : null;
  }
  if (!context.mounted) return null;

  return showPickerSheet<MoneyAccount>(
    context: context,
    title: title,
    hint: 'Account name',
    search: search,
    emptyTitle: 'No account matches',
    itemBuilder: (account, select) => AppListRow(
      leading: IconPlate(
        icon: account.isCash
            ? Icons.payments_rounded
            : Icons.account_balance_rounded,
        color: context.palette.brand,
      ),
      title: account.name,
      subtitle: account.isCash
          ? 'In hand'
          : account.accountNo ?? account.accountType.label,
      trailing: [RowAmount(account.balance.display(decimals: false))],
      onTap: select,
    ),
  );
}

/// The fields most entries never need, folded away so the form fits the screen.
class MoreDetails extends StatefulWidget {
  const MoreDetails({
    super.key,
    required this.children,
    this.label = 'More details',
  });

  final List<Widget> children;
  final String label;

  @override
  State<MoreDetails> createState() => _MoreDetailsState();
}

class _MoreDetailsState extends State<MoreDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.xs,
              vertical: AppSizes.sm,
            ),
            child: Row(
              children: [
                Icon(
                  _open
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: palette.brand,
                ),
                AppSizes.gapXs,
                Text(
                  widget.label,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: palette.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Kept in the tree while closed, so a field that failed validation or
        // already holds text is not thrown away by folding the section.
        Offstage(
          offstage: !_open,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.sm),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.children.length; i++) ...[
                    if (i > 0) AppSizes.gapMd,
                    widget.children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Two small cells side by side at the top of a form: the document's number and
/// its date, the row every paper bill starts with.
class DocHeader extends StatelessWidget {
  const DocHeader({
    super.key,
    required this.numberLabel,
    required this.number,
    required this.date,
    required this.onDate,
    this.numberHint,
    this.numberValidator,
  });

  final String numberLabel;
  final TextEditingController number;
  final String? numberHint;
  final String? Function(String?)? numberValidator;
  final int date;
  final ValueChanged<int> onDate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AppTextField(
              label: numberLabel,
              controller: number,
              hint: numberHint,
              validator: numberValidator,
              textInputAction: TextInputAction.next,
            ),
          ),
          AppSizes.gapMd,
          Expanded(
            flex: 3,
            child: DateField(label: 'Date', value: date, onChanged: onDate),
          ),
        ],
      ),
    );
  }
}
