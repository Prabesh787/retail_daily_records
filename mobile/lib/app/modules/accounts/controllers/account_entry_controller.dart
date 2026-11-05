import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/account_choice.dart';
import '../../../core/domain/money.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../routes/app_nav.dart';

/// The three ways money moves with no party attached.
enum EntryType {
  transfer('Transfer'),
  moneyIn('Money in'),
  moneyOut('Money out');

  const EntryType(this.label);

  final String label;
}

/// Bank deposits, withdrawals and transfers between accounts; expenses and owner
/// drawings; and corrections. Without this a cash balance drifts from the box the
/// first time cash goes to the bank.
class AccountEntryController extends GetxController {
  final AccountRepository _accounts = Get.find<AccountRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController amount = TextEditingController();
  final TextEditingController description = TextEditingController();

  final Rx<EntryType> type = EntryType.transfer.obs;
  final AccountChoice from = AccountChoice();
  final AccountChoice to = AccountChoice();
  final RxInt date = AppDateUtils.startOfTodayMs().obs;
  final RxBool isSaving = false.obs;

  bool get needsFrom => type.value != EntryType.moneyIn;
  bool get needsTo => type.value != EntryType.moneyOut;

  void setType(EntryType value) {
    type.value = value;
    from.error.value = null;
    to.error.value = null;
  }

  void setDate(int ms) => date.value = ms;

  Future<void> save() async {
    final formValid = formKey.currentState?.validate() ?? false;
    final fromValid = !needsFrom || from.validate('Choose the account');
    final toValid = !needsTo || to.validate('Choose the account');
    if (!formValid || !fromValid || !toValid) return;
    if (isSaving.value) return;

    isSaving.value = true;
    try {
      final note = description.text.trim();
      await _accounts.saveEntry(
        dateMs: date.value,
        amount: Money.tryParse(amount.text) ?? Money.zero,
        fromAccountId: needsFrom ? from.id : null,
        toAccountId: needsTo ? to.id : null,
        description: note.isNotEmpty
            ? note
            : type.value == EntryType.transfer
            ? '${from.selected.value!.name} to ${to.selected.value!.name}'
            : null,
      );

      AppToast.success('Recorded');
      AppNav.back<void>();
    } on ValidationException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not record this. $e');
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    amount.dispose();
    description.dispose();
    super.onClose();
  }
}
