import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/domain/money.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/ledger.dart';
import '../../../data/models/money_account.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../routes/app_pages.dart';

/// What one account's ledger reads, in one load.
class AccountLedger {
  const AccountLedger({required this.account, required this.rows});

  /// Null for the movements that have no bank named.
  final MoneyAccount? account;

  /// Newest first, each carrying the balance it left behind.
  final List<AccountMovement> rows;

  Money get balance => rows.isNotEmpty
      ? rows.first.balanceAfter
      : (account?.openingBalance ?? Money.zero);

  Money get moneyIn =>
      Money.sum(rows.where((r) => r.isIn).map((r) => r.amount));

  Money get moneyOut =>
      Money.sum(rows.where((r) => !r.isIn).map((r) => r.amount));
}

/// One account's cash book: every rupee in and out, with a running balance.
class AccountDetailController extends LoaderController<AccountLedger> {
  final AccountRepository _accounts = Get.find<AccountRepository>();

  String? accountId;

  @override
  List<String> get watches => const [
    DbTables.account,
    DbTables.accountEntry,
    DbTables.sale,
    DbTables.supplierPayment,
    DbTables.customerPayment,
  ];

  AccountLedger? get ledger => data.value;

  @override
  void onInit() {
    final args = Get.arguments;
    accountId = args is Map ? args[RouteArgs.accountId] as String? : null;
    super.onInit();
  }

  @override
  Future<AccountLedger> fetch() async {
    final id = accountId;
    final account = id == null ? null : await _accounts.byId(id);

    return AccountLedger(
      account: account,
      rows: await _accounts.ledger(account),
    );
  }

  void edit() => Get.toNamed<void>(
    Routes.accountForm,
    arguments: {RouteArgs.accountId: accountId},
  );

  /// Each line opens the record behind it. A manual entry has no screen of its
  /// own, so tapping one offers the only thing that can happen to it.
  Future<void> open(AccountMovement row) async {
    switch (row.source) {
      case MovementSource.sale:
        await Get.toNamed<void>(
          Routes.saleDetail,
          arguments: {RouteArgs.saleId: row.recordId},
        );
      case MovementSource.customerPayment:
        await Get.toNamed<void>(
          Routes.receiptDetail,
          arguments: {RouteArgs.paymentId: row.recordId},
        );
      case MovementSource.supplierPayment:
        await Get.toNamed<void>(
          Routes.paymentDetail,
          arguments: {RouteArgs.paymentId: row.recordId},
        );
      case MovementSource.entry:
        await _deleteEntry(row);
    }
  }

  Future<void> _deleteEntry(AccountMovement row) async {
    final confirmed = await ConfirmDialog.show(
      title: 'Delete this entry?',
      message:
          '${row.title}, ${row.amount.display()}. The balance goes back to what '
          'it would have been without it.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await _accounts.deleteEntry(row.recordId);
      AppToast.success('Entry deleted');
    } catch (e) {
      AppToast.error('Could not delete this entry. $e');
    }
  }
}
