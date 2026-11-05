import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/domain/money.dart';
import '../../../data/models/ledger.dart';
import '../../../data/models/money_account.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../routes/app_pages.dart';

/// What the Accounts tab shows: the balances, and the cheques still out.
class AccountsBoard {
  const AccountsBoard({required this.overview, required this.cheques});

  final AccountsOverview overview;
  final List<ChequeItem> cheques;

  Iterable<ChequeItem> get toCollect =>
      cheques.where((c) => c.direction == ChequeDirection.toCollect);

  Iterable<ChequeItem> get toPay =>
      cheques.where((c) => c.direction == ChequeDirection.toPay);

  Money get collectTotal => Money.sum(toCollect.map((c) => c.amount));
  Money get payTotal => Money.sum(toPay.map((c) => c.amount));
}

/// The Accounts tab.
///
/// Balances move when money moves, and money moves on a sale, a purchase, either
/// kind of payment or a manual entry, so this watches all of them.
class AccountsController extends LoaderController<AccountsBoard> {
  final AccountRepository _accounts = Get.find<AccountRepository>();
  final ActivityRepository _activity = Get.find<ActivityRepository>();

  @override
  List<String> get watches => const [
    DbTables.account,
    DbTables.accountEntry,
    DbTables.sale,
    DbTables.supplierPayment,
    DbTables.customerPayment,
  ];

  AccountsBoard? get board => data.value;

  @override
  Future<AccountsBoard> fetch() async => AccountsBoard(
    overview: await _accounts.overview(),
    cheques: await _activity.cheques(),
  );

  void openAccount(MoneyAccount account) => Get.toNamed<void>(
    Routes.accountDetail,
    arguments: {RouteArgs.accountId: account.id},
  );

  /// The bank money with no bank named. A detail screen with no id reads those.
  void openUnassigned() => Get.toNamed<void>(Routes.accountDetail);

  void addAccount() => Get.toNamed<void>(Routes.accountForm);

  void openCheques() => Get.toNamed<void>(Routes.cheques);

  void newEntry() => Get.toNamed<void>(Routes.accountEntry);
}
