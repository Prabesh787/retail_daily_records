import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/enums/payment_status.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/supplier_payment_repository.dart';
import '../../../routes/app_pages.dart';

/// One payment, and the two things that can still happen to it.
class PaymentDetailController extends LoaderController<SupplierPayment> {
  final SupplierPaymentRepository _payments =
      Get.find<SupplierPaymentRepository>();

  late final String paymentId;

  final RxBool isActing = false.obs;

  @override
  List<String> get watches => const [DbTables.supplierPayment];

  SupplierPayment? get payment => data.value;

  /// Clearing applies to a cheque that is still out. Cash was already cleared
  /// when it was recorded, and a cancelled cheque is not waiting for anything.
  bool get canClear => payment?.status == PaymentStatus.issued;

  /// Cancelling applies to anything not already cancelled — a bounced cheque
  /// and a payment entered by mistake take the same route out.
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
  Future<SupplierPayment> fetch() async {
    final result = await _payments.byId(paymentId);
    if (result == null) {
      throw const AppException('This payment is no longer in your records.');
    }
    return result;
  }

  /// The bank took it. Nothing about what the supplier is owed changes — an
  /// issued cheque already counted against the balance — so this moves the
  /// money from "promised" to "gone" and nothing else.
  Future<void> clear() async {
    final current = payment;
    if (current == null || isActing.value) return;

    final confirmed = await ConfirmDialog.show(
      title: 'Mark cheque ${current.chequeNo} as cleared?',
      message: 'Use this once the bank has actually taken the money. What you '
          'owe this supplier does not change — it already counted.',
      confirmLabel: 'Mark cleared',
    );
    if (!confirmed) return;

    isActing.value = true;
    try {
      await _payments.markCleared(paymentId);
      AppToast.success('Marked as cleared');
    } catch (e) {
      AppToast.error('Could not update this payment. $e');
    } finally {
      isActing.value = false;
    }
  }

  /// Cancelling is not deleting. The row stays on the statement for the audit
  /// trail and settles nothing, which is why the supplier's balance goes *up*
  /// by the amount — the message says so before it happens.
  Future<void> cancel() async {
    final current = payment;
    if (current == null || isActing.value) return;

    final confirmed = await ConfirmDialog.show(
      title: 'Cancel this payment?',
      message:
          'For a bounced cheque or one entered by mistake. It stays on the '
          'statement as a cancelled line, and ${current.amount.display()} goes '
          'back onto what you owe ${current.supplierName ?? 'this supplier'}.',
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

  void openSupplier() {
    final supplierId = payment?.supplierId;
    if (supplierId == null) return;

    Get.toNamed<void>(
      Routes.supplierDetail,
      arguments: {RouteArgs.supplierId: supplierId},
    );
  }

  void openBill() {
    final purchaseId = payment?.purchaseId;
    if (purchaseId == null) return;

    Get.toNamed<void>(
      Routes.purchaseDetail,
      arguments: {RouteArgs.purchaseId: purchaseId},
    );
  }
}
