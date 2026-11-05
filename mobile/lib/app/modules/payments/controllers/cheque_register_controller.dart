import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/domain/money.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/ledger.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../routes/app_pages.dart';
import '../views/clear_cheque_sheet.dart';

/// Every cheque, both ways, in the order the money is due.
///
/// A cheque is a commitment with a date on it. Sorted by the date written on it
/// rather than the day it changed hands, this answers the two questions a shop
/// has about cheques: what has to be in the account by when, and what is due to
/// come in.
class ChequeRegisterController extends LoaderController<List<ChequeItem>> {
  final ActivityRepository _activity = Get.find<ActivityRepository>();

  /// Cleared cheques are history; the register is a forward-looking list. The
  /// toggle is there because reconciling last month means looking back.
  final RxBool onlyPending = true.obs;

  /// Null shows both directions.
  final Rxn<ChequeDirection> direction = Rxn<ChequeDirection>();

  @override
  List<String> get watches => const [
    DbTables.supplierPayment,
    DbTables.customerPayment,
    DbTables.sale,
    DbTables.account,
  ];

  List<ChequeItem> get _all => data.value ?? const [];

  List<ChequeItem> get rows {
    final filter = direction.value;
    return filter == null
        ? _all
        : _all.where((c) => c.direction == filter).toList();
  }

  @override
  bool get isEmpty => rows.isEmpty;

  @override
  Future<List<ChequeItem>> fetch() =>
      _activity.cheques(onlyPending: onlyPending.value);

  /// Overdue, due within the week, and everything later.
  ///
  /// Those three because they are three different actions: chase it, make sure
  /// the money is there, and nothing yet.
  ({
    List<ChequeItem> overdue,
    List<ChequeItem> week,
    List<ChequeItem> later,
    List<ChequeItem> settled,
  }) get buckets {
    final overdue = <ChequeItem>[];
    final week = <ChequeItem>[];
    final later = <ChequeItem>[];
    final settled = <ChequeItem>[];

    for (final cheque in rows) {
      if (!cheque.isPending) {
        settled.add(cheque);
      } else if (cheque.daysLeft < 0) {
        overdue.add(cheque);
      } else if (cheque.daysLeft <= 7) {
        week.add(cheque);
      } else {
        later.add(cheque);
      }
    }

    return (overdue: overdue, week: week, later: later, settled: settled);
  }

  Money _pendingTotal(ChequeDirection side) => Money.sum(
    _all
        .where((c) => c.isPending && c.direction == side)
        .map((c) => c.amount),
  );

  Money get toCollect => _pendingTotal(ChequeDirection.toCollect);
  Money get toPay => _pendingTotal(ChequeDirection.toPay);

  void setOnlyPending(bool value) {
    onlyPending.value = value;
    load(silent: true);
  }

  void setDirection(ChequeDirection? value) => direction.value = value;

  void open(ChequeItem cheque) {
    switch (cheque.source) {
      case ChequeSource.saleLine:
        Get.toNamed<void>(
          Routes.saleDetail,
          arguments: {RouteArgs.saleId: cheque.parentId},
        );
      case ChequeSource.customerPayment:
        Get.toNamed<void>(
          Routes.receiptDetail,
          arguments: {RouteArgs.paymentId: cheque.id},
        );
      case ChequeSource.supplierPayment:
        Get.toNamed<void>(
          Routes.paymentDetail,
          arguments: {RouteArgs.paymentId: cheque.id},
        );
    }
  }

  Future<void> clear(BuildContext context, ChequeItem cheque) async {
    final toCollect = cheque.direction == ChequeDirection.toCollect;
    final today = AppDateUtils.startOfTodayMs();

    final choice = await showClearChequeSheet(
      context,
      title: 'Cheque ${cheque.chequeNo ?? ''} cleared'.trim(),
      accountLabel: toCollect ? 'Deposited in' : 'Paid from',
      earliestMs: cheque.issuedMs,
      // Never suggests a date in the future or before the cheque existed: the
      // server refuses a cheque cleared before it was issued.
      suggestedMs: today < cheque.issuedMs ? cheque.issuedMs : today,
      presetAccountId: cheque.accountId,
    );
    if (choice == null) return;

    try {
      await _activity.clearCheque(
        cheque,
        accountId: choice.account.id,
        clearedOnMs: choice.clearedOnMs,
      );
      AppToast.success(
        toCollect
            ? 'Added to ${choice.account.name}'
            : 'Taken from ${choice.account.name}',
      );
    } catch (e) {
      AppToast.error('Could not update this cheque. $e');
    }
  }

  Future<void> bounce(ChequeItem cheque) async {
    final toCollect = cheque.direction == ChequeDirection.toCollect;

    final confirmed = await ConfirmDialog.show(
      title: toCollect ? 'Did this cheque bounce?' : 'Cancel this cheque?',
      message: toCollect
          ? '${cheque.amount.display()} goes back onto what '
                '${cheque.partyName ?? 'this customer'} owes. The cheque stays '
                'on record as cancelled.'
          : '${cheque.amount.display()} goes back onto what you owe '
                '${cheque.partyName ?? 'this supplier'}. The cheque stays on '
                'record as cancelled.',
      confirmLabel: toCollect ? 'It bounced' : 'Cancel cheque',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await _activity.cancelCheque(cheque);
      AppToast.success('Cheque cancelled');
    } catch (e) {
      AppToast.error('Could not update this cheque. $e');
    }
  }
}
