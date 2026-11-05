import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/ledger.dart';
import '../controllers/account_detail_controller.dart';

/// The cash book for one account.
class AccountDetailView extends GetView<AccountDetailController> {
  const AccountDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ledger = controller.ledger;
      final account = ledger?.account;

      return AppScreen(
        title: account?.name ?? 'Bank not named',
        back: true,
        onRefresh: controller.reload,
        actions: [
          if (account != null)
            IconButton(
              tooltip: 'Edit account',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: controller.edit,
            ),
        ],
        child: _body(context, ledger),
      );
    });
  }

  Widget _body(BuildContext context, AccountLedger? ledger) {
    if (controller.isLoading.value) return const SkeletonRows();

    final message = controller.error.value;
    if (message != null || ledger == null) {
      return ErrorView(
        message: message ?? 'This account could not be loaded.',
        onRetry: controller.reload,
      );
    }

    final palette = context.palette;
    final groups = groupByDay<AccountMovement>(
      ledger.rows,
      (row) => row.movedOn,
      (row) => row.isIn ? row.amount : -row.amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BALANCE',
                style: AppTextStyles.label.copyWith(color: palette.inkSubtle),
              ),
              Text(
                ledger.balance.display(),
                style: AppTextStyles.display.copyWith(
                  color: ledger.balance.isNegative
                      ? palette.moneyOut
                      : palette.ink,
                ),
              ),
              AppSizes.gapXs,
              Text(
                [
                  if (ledger.account?.openingBalance case final opening?
                      when !opening.isZero)
                    'Opening ${opening.display(decimals: false)}',
                  'In ${ledger.moneyIn.display(decimals: false)}',
                  'Out ${ledger.moneyOut.display(decimals: false)}',
                ].join(' · '),
                style: AppTextStyles.caption.copyWith(color: palette.inkMuted),
              ),
            ],
          ),
        ),
        AppSizes.gapMd,

        if (ledger.rows.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No money has moved yet',
            message: 'Sales, payments and entries through this account will '
                'be listed here.',
          )
        else
          for (final group in groups) ...[
            AppCard.flush(
              child: Column(
                children: [
                  GroupHeader(label: AppDateUtils.relativeDay(group.dateMs)),
                  for (var i = 0; i < group.rows.length; i++) ...[
                    if (i > 0) const RowDivider(),
                    AppListRow(
                      leading: Icon(
                        group.rows[i].isIn
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 18,
                        color: group.rows[i].isIn
                            ? palette.moneyIn
                            : palette.moneyOut,
                      ),
                      title: group.rows[i].title,
                      trailing: [
                        RowAmount(
                          group.rows[i].amount.display(decimals: false),
                          tone: group.rows[i].isIn
                              ? MoneyTone.inbound
                              : MoneyTone.outbound,
                        ),
                        RowCaption(
                          'Bal ${group.rows[i].balanceAfter.display(decimals: false)}',
                        ),
                      ],
                      onTap: () => controller.open(group.rows[i]),
                    ),
                  ],
                ],
              ),
            ),
            AppSizes.gapMd,
          ],
      ],
    );
  }
}
