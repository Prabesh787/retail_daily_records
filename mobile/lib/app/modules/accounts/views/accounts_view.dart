import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/money_account.dart';
import '../controllers/accounts_controller.dart';

/// The Accounts tab: how much money there is, where it sits, and which cheques
/// are about to change that.
class AccountsView extends GetView<AccountsController> {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Accounts',
      onRefresh: controller.reload,
      bottomBar: AppButton(
        label: 'Move money',
        icon: Icons.swap_horiz_rounded,
        onPressed: controller.newEntry,
      ),
      child: Obx(() {
        if (controller.isLoading.value) return const SkeletonRows();

        final message = controller.error.value;
        final board = controller.board;
        if (message != null || board == null) {
          return ErrorView(
            message: message ?? 'The accounts could not be loaded.',
            onRetry: controller.reload,
          );
        }

        final palette = context.palette;
        final overview = board.overview;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL BALANCE',
                    style: AppTextStyles.label.copyWith(
                      color: palette.inkSubtle,
                    ),
                  ),
                  Text(
                    overview.total.display(),
                    style: AppTextStyles.display.copyWith(
                      color: overview.total.isNegative
                          ? palette.moneyOut
                          : palette.ink,
                    ),
                  ),
                  AppSizes.gapXs,
                  Text(
                    'Cash ${overview.cash.display(decimals: false)} · '
                    'Bank ${overview.bank.display(decimals: false)}',
                    style: AppTextStyles.caption.copyWith(
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.gapMd,

            SectionHeader(
              title: 'YOUR ACCOUNTS',
              action: '+ New account',
              onAction: controller.addAccount,
            ),
            AppCard.flush(
              child: Column(
                children: [
                  for (var i = 0; i < overview.accounts.length; i++) ...[
                    if (i > 0) const RowDivider(),
                    _AccountRow(
                      account: overview.accounts[i],
                      onTap: () =>
                          controller.openAccount(overview.accounts[i]),
                    ),
                  ],
                  if (!overview.unassigned.isZero) ...[
                    const RowDivider(),
                    AppListRow(
                      leading: IconPlate(
                        icon: Icons.help_outline_rounded,
                        color: palette.pending,
                        size: 36,
                      ),
                      title: 'Bank not named',
                      subtitle: 'Older records with no bank chosen',
                      trailing: [
                        RowAmount(overview.unassigned.display(decimals: false)),
                      ],
                      chevron: true,
                      onTap: controller.openUnassigned,
                    ),
                  ],
                ],
              ),
            ),
            AppSizes.gapMd,

            SectionHeader(
              title: 'CHEQUES NOT CLEARED',
              action: 'See all',
              onAction: controller.openCheques,
            ),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'TO COLLECT',
                    value: board.collectTotal.display(decimals: false),
                    foot: '${board.toCollect.length} waiting',
                    tone: MoneyTone.inbound,
                    onTap: controller.openCheques,
                  ),
                ),
                AppSizes.gapSm,
                Expanded(
                  child: StatTile(
                    label: 'TO PAY',
                    value: board.payTotal.display(decimals: false),
                    foot: '${board.toPay.length} to fund',
                    tone: MoneyTone.outbound,
                    onTap: controller.openCheques,
                  ),
                ),
              ],
            ),
            AppSizes.gapLg,
          ],
        );
      }),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onTap});

  final MoneyAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppListRow(
      leading: IconPlate(
        icon: account.isCash
            ? Icons.payments_rounded
            : Icons.account_balance_rounded,
        color: account.isCash ? palette.moneyIn : palette.brand,
        size: 36,
      ),
      title: account.name,
      subtitle: account.isCash
          ? 'In hand'
          : account.accountNo ?? account.accountType.label,
      trailing: [
        RowAmount(
          account.balance.display(decimals: false),
          tone: account.balance.isNegative
              ? MoneyTone.outbound
              : MoneyTone.plain,
        ),
      ],
      chevron: true,
      onTap: onTap,
    );
  }
}
