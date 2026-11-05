import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/controllers/scan_capture.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/domain/scan_viewer.dart';
import '../../../data/enums/document_type.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../data/repositories/supplier_payment_repository.dart';
import '../../../routes/app_pages.dart';

typedef PurchaseDetail = ({
  Purchase bill,
  List<SupplierPayment> payments,
  List<ScanFile> scans,
});

/// One bill, everything paid against it, and the scan of the paper it came on.
class PurchaseDetailController extends LoaderController<PurchaseDetail> {
  final PurchaseRepository _purchases = Get.find<PurchaseRepository>();
  final SupplierPaymentRepository _payments =
      Get.find<SupplierPaymentRepository>();

  late final String purchaseId;

  late final RecordScans _scans = RecordScans(
    entityType: AttachmentEntityType.purchase,
    entityId: purchaseId,
    paper: 'bill',
    record: 'bill',
  );

  RxBool get isAttaching => _scans.isAttaching;

  @override
  List<String> get watches => const [
    DbTables.purchase,
    DbTables.supplierPayment,
    DbTables.attachment,
  ];

  Purchase? get bill => data.value?.bill;
  List<SupplierPayment> get payments => data.value?.payments ?? const [];
  List<ScanFile> get scans => data.value?.scans ?? const [];

  @override
  void onInit() {
    final args = Get.arguments;
    purchaseId =
        (args is Map ? args[RouteArgs.purchaseId] as String? : null) ?? '';
    super.onInit();
  }

  @override
  Future<PurchaseDetail> fetch() async {
    final bill = await _purchases.byId(purchaseId);
    if (bill == null) {
      throw const AppException('This bill is no longer in your records.');
    }

    // Fetched separately rather than joined: a bill's payments are a short list
    // read only on this screen, and loading them with every list query would
    // cost every other screen for one.
    final payments = await _payments.list(purchaseId: purchaseId);

    return (bill: bill, payments: payments, scans: await _scans.load());
  }

  /// Photographs the paper bill, or picks a photo already taken, and files it
  /// against this purchase.
  Future<void> attachScan() => _scans.attach(DocumentType.purchaseBill);

  void openScan(ScanFile scan) =>
      _scans.open(scan, title: 'Bill ${bill?.billNo ?? ''}'.trim());

  void openSupplier() {
    final supplierId = bill?.supplierId;
    if (supplierId == null) return;

    Get.toNamed<void>(
      Routes.supplierDetail,
      arguments: {RouteArgs.supplierId: supplierId},
    );
  }

  void openPayment(SupplierPayment payment) => Get.toNamed<void>(
    Routes.paymentDetail,
    arguments: {RouteArgs.paymentId: payment.id},
  );

  /// Opens the payment form already pointed at this bill, so the payment lands
  /// against it rather than floating against the supplier in general.
  void recordPayment() {
    final current = bill;
    if (current == null) return;

    Get.toNamed<void>(
      Routes.paymentForm,
      arguments: {
        RouteArgs.presetSupplierId: current.supplierId,
        RouteArgs.presetPurchaseId: current.id,
      },
    );
  }
}
