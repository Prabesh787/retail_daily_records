import 'package:get/get.dart';

import '../../data/models/money_account.dart';
import '../../data/repositories/account_repository.dart';

/// The "which bank?" state every money form shares.
///
/// Not a controller of its own: it lives and dies with the form that owns it.
class AccountChoice {
  final Rxn<MoneyAccount> selected = Rxn<MoneyAccount>();
  final RxnString error = RxnString();

  String? get id => selected.value?.id;

  void set(MoneyAccount? account) {
    selected.value = account;
    error.value = null;
  }

  /// With a single bank there is no question to ask, so it is answered already.
  Future<void> preselectOnlyBank() async {
    if (selected.value != null) return;

    final banks = await searchBanks('');
    if (banks.length == 1) set(banks.first);
  }

  /// Marks the slot invalid when nothing is chosen. Returns whether it is valid.
  bool validate([String message = 'Choose the bank or wallet']) {
    if (selected.value != null) return true;
    error.value = message;
    return false;
  }

  /// Banks and wallets. The cash box is not one, whatever the search says.
  static Future<List<MoneyAccount>> searchBanks(String query) =>
      _search(query, includeCash: false);

  /// Every account, for clearing a cheque or moving money.
  static Future<List<MoneyAccount>> searchAll(String query) =>
      _search(query, includeCash: true);

  static Future<List<MoneyAccount>> _search(
    String query, {
    required bool includeCash,
  }) async {
    final term = query.trim().toLowerCase();
    final accounts = await Get.find<AccountRepository>().list();

    return accounts
        .where((a) => includeCash || !a.isCash)
        .where((a) => term.isEmpty || a.name.toLowerCase().contains(term))
        .toList();
  }
}
