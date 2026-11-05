import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/controllers/scan_capture.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/domain/scan_viewer.dart';
import '../../../data/enums/document_type.dart';
import '../../../data/enums/payment_status.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/supplier_payment_repository.dart';
import '../../../routes/app_pages.dart';
import '../views/clear_cheque_sheet.dart';

typedef PaymentDetail = ({SupplierPayment payment, List<ScanFile> scans});

/// One payment, the two things that can still happen to it, and the scan of the
/// paper behind it.
class PaymentDetailController extends LoaderController<PaymentDetail> {
  final SupplierPaymentRepository _payments =
      Get.find<SupplierPaymentRepository>();

  late final String paymentId;

  late final RecordScans _scans = RecordScans(
    entityType: AttachmentEntityType.supplierPayment,
    entityId: paymentId,
    paper: 'receipt',
    record: 'payment',
  );

  final RxBool isActing = false.obs;

  RxBool get isAttaching => _scans.isAttaching;

  @override
  List<String> get watches => const [
    DbTables.supplierPayment,
    DbTables.attachment,
  ];

  SupplierPayment? get payment => data.value?.payment;
  List<ScanFile> get scans => data.value?.scans ?? const [];

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
  Future<PaymentDetail> fetch() async {
    final result = await _payments.byId(paymentId);
    if (result == null) {
      throw const AppException('This payment is no longer in your records.');
    }
    return (payment: result, scans: await _scans.load());
  }

  /// Photographs the receipt or cheque, or picks a photo already taken, and
  /// files it against this payment.
  Future<void> attachScan() => _scans.attach(
    payment?.paymentMode.isCheque ?? false
        ? DocumentType.chequeCopy
        : DocumentType.supplierPaymentReceipt,
  );

  void openScan(ScanFile scan) =>
      _scans.open(scan, title: payment?.supplierName ?? 'Payment');

  /// The bank took it. Nothing about what the supplier is owed changes — an
  /// issued cheque already counted against the balance — but this is the moment
  /// the money leaves an account, which is why clearing names the account.
  Future<void> clear(BuildContext context) async {
    final current = payment;
    if (current == null || isActing.value) return;

    final choice = await showClearChequeSheet(
      context,
      title: 'Cheque ${current.chequeNo} cleared',
      accountLabel: 'Paid from',
      earliestMs: current.paymentDate,
      suggestedMs: current.chequeDate ?? current.paymentDate,
      presetAccountId: current.accountId,
    );
    if (choice == null) return;

    isActing.value = true;
    try {
      await _payments.markCleared(
        paymentId,
        clearedOnMs: choice.clearedOnMs,
        accountId: choice.account.id,
      );
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
