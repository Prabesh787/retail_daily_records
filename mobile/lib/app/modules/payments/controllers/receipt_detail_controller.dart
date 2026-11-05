import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/enums/payment_status.dart';
import '../../../data/models/customer_payment.dart';
import '../../../data/repositories/customer_payment_repository.dart';
import '../../../routes/app_pages.dart';
import '../views/clear_cheque_sheet.dart';

/// One Payment In, and the two things that can still happen to it.
class ReceiptDetailController extends LoaderController<CustomerPayment> {
  final CustomerPaymentRepository _payments =
      Get.find<CustomerPaymentRepository>();

  late final String paymentId;

  final RxBool isActing = false.obs;

  @override
  List<String> get watches => const [DbTables.customerPayment];

  CustomerPayment? get payment => data.value;

  bool get canClear => payment?.status == PaymentStatus.issued;

  bool get canCancel =>
      payment != null && payment!.status != PaymentStatus.cancelled;

  @override
  void onInit() {
    final args = Get.arguments;
    paymentId =
        (args is Map ? args[RouteArgs.paymentId] as String? : null) ?? '';
    super.onInit();
  }

  @override
  Future<CustomerPayment> fetch() async {
    final result = await _payments.byId(paymentId);
    if (result == null) {
      throw const AppException('This payment is no longer in your records.');
    }
    return result;
  }

  Future<void> clear(BuildContext context) async {
    final current = payment;
    if (current == null || isActing.value) return;

    final today = AppDateUtils.startOfTodayMs();
    final choice = await showClearChequeSheet(
      context,
      title: 'Cheque ${current.chequeNo} cleared',
      accountLabel: 'Deposited in',
      earliestMs: current.paymentDate,
      // The server refuses a cheque cleared before it was received.
      suggestedMs: today < current.paymentDate ? current.paymentDate : today,
    );
    if (choice == null) return;

    isActing.value = true;
    try {
      await _payments.markCleared(
        paymentId,
        accountId: choice.account.id,
        clearedOnMs: choice.clearedOnMs,
      );
      AppToast.success('Added to ${choice.account.name}');
    } catch (e) {
      AppToast.error('Could not update this payment. $e');
    } finally {
      isActing.value = false;
    }
  }

  Future<void> cancel() async {
    final current = payment;
    if (current == null || isActing.value) return;

    final confirmed = await ConfirmDialog.show(
      title: 'Cancel this payment?',
      message:
          'For a bounced cheque or one entered by mistake. It stays on record '
          'as cancelled, and ${current.amount.display()} goes back onto what '
          '${current.customerName ?? 'this customer'} owes.',
      confirmLabel: 'Cancel payment',
      isDestructive: true,
    );
    if (!confirmed) return;

    isActing.value = true;
    try {
      await _payments.markCancelled(paymentId);
      AppToast.success('Payment cancelled');
    } catch (e) {
      AppToast.error('Could not cancel this payment. $e');
    } finally {
      isActing.value = false;
    }
  }
}
