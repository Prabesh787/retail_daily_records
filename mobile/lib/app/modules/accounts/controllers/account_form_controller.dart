import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/money.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/enums/account_type.dart';
import '../../../data/models/money_account.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../routes/app_nav.dart';
import '../../../routes/app_pages.dart';

/// Adding or editing a bank, a wallet, or the cash box's opening balance.
class AccountFormController extends GetxController {
  final AccountRepository _accounts = Get.find<AccountRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController name = TextEditingController();
  final TextEditingController accountNo = TextEditingController();
  final TextEditingController opening = TextEditingController();

  final Rx<AccountType> type = AccountType.bank.obs;
  final RxBool isActive = true.obs;
  final RxBool isSaving = false.obs;
  final RxBool isLoading = false.obs;

  String? _id;
  MoneyAccount? _existing;

  bool get isEdit => _id != null;
  bool get isCash => _existing?.isCash ?? false;
  String get title => isEdit ? 'Edit account' : 'New account';

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;
    if (args is Map && args[RouteArgs.accountId] is String) {
      _id = args[RouteArgs.accountId] as String;
      _load();
    }
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      final account = await _accounts.byId(_id!);
      if (account == null) {
        AppToast.error('That account no longer exists.');
        AppNav.back<void>();
        return;
      }

      _existing = account;
      name.text = account.name;
      accountNo.text = account.accountNo ?? '';
      opening.text = account.openingBalance.isZero
          ? ''
          : account.openingBalance.toWire();
      type.value = account.accountType;
      isActive.value = account.isActive;
    } finally {
      isLoading.value = false;
    }
  }

  void setType(AccountType value) => type.value = value;

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (isSaving.value) return;

    final number = accountNo.text.trim();
    final openingBalance = Money.tryParse(opening.text) ?? Money.zero;

    isSaving.value = true;
    try {
      final existing = _existing;
      final saved = await _accounts.save(
        existing != null
            ? existing.copyWith(
                name: name.text.trim(),
                accountType: type.value,
                accountNo: number.isEmpty ? null : number,
                openingBalance: openingBalance,
                isActive: isActive.value,
              )
            : MoneyAccount(
                id: '',
                createdAt: 0,
                updatedAt: 0,
                name: name.text.trim(),
                accountType: type.value,
                accountNo: number.isEmpty ? null : number,
                openingBalance: openingBalance,
              ),
      );

      AppToast.success(isEdit ? 'Account updated' : '${saved.name} added');
      // Back to whichever form asked for a new account, carrying the answer.
      AppNav.back<MoneyAccount>(saved);
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save this account. $e');
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    for (final field in [name, accountNo, opening]) {
      field.dispose();
    }
    super.onClose();
  }
}
