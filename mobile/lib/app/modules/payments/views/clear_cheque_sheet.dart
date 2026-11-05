import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/controllers/account_choice.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/money_account.dart';

/// Asks the two things clearing a cheque needs: which account the money moved
/// through, and on what day. Completes with null if dismissed.
Future<({MoneyAccount account, int clearedOnMs})?> showClearChequeSheet(
  BuildContext context, {
  required String title,
  required String accountLabel,
  required int earliestMs,
  required int suggestedMs,
  String? presetAccountId,
}) {
  return AppSheet.show<({MoneyAccount account, int clearedOnMs})>(
    context: context,
    title: title,
    child: _ClearChequeBody(
      accountLabel: accountLabel,
      earliestMs: earliestMs,
      suggestedMs: suggestedMs,
      presetAccountId: presetAccountId,
    ),
  );
}

class _ClearChequeBody extends StatefulWidget {
  const _ClearChequeBody({
    required this.accountLabel,
    required this.earliestMs,
    required this.suggestedMs,
    this.presetAccountId,
  });

  final String accountLabel;
  final int earliestMs;
  final int suggestedMs;
  final String? presetAccountId;

  @override
  State<_ClearChequeBody> createState() => _ClearChequeBodyState();
}

class _ClearChequeBodyState extends State<_ClearChequeBody> {
  final AccountChoice _account = AccountChoice();
  late int _date = widget.suggestedMs;

  @override
  void initState() {
    super.initState();
    _preselect();
  }

  Future<void> _preselect() async {
    final accounts = await AccountChoice.searchBanks('');
    final preset = accounts.where((a) => a.id == widget.presetAccountId);

    if (preset.isNotEmpty) {
      _account.set(preset.first);
    } else if (accounts.length == 1) {
      _account.set(accounts.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        0,
        AppSizes.lg,
        AppSizes.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountField(label: widget.accountLabel, choice: _account),
          AppSizes.gapMd,
          DateField(
            label: 'Cleared on',
            value: _date,
            firstDate: AppDateUtils.fromMs(widget.earliestMs),
            onChanged: (ms) => setState(() => _date = ms),
          ),
          AppSizes.gapLg,
          AppButton(
            label: 'Mark as cleared',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () {
              if (!_account.validate('Choose the account')) return;
              Navigator.of(context).pop((
                account: _account.selected.value!,
                clearedOnMs: _date,
              ));
            },
          ),
        ],
      ),
    );
  }
}
