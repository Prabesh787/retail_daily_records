import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../data/repositories/supplier_payment_repository.dart';
import '../../../routes/app_pages.dart';

/// One bill, and everything paid against it.
class PurchaseDetailController
    extends LoaderController<({Purchase bill, List<SupplierPayment> payments})> {
  final PurchaseRepository _purchases = Get.find<PurchaseRepository>();
  final SupplierPaymentRepository _payments =
      Get.find<SupplierPaymentRepository>();

  late final String purchaseId;

  @override
  List<String> get watches => const [
    DbTables.purchase,
    DbTables.supplierPayment,
  ];

  Purchase? get bill => data.value?.bill;
  List<SupplierPayment> get payments => data.value?.payments ?? const [];

  @override
  void onInit() {
    final args = Get.arguments;
    purchaseId =
        (args is Map ? args[RouteArgs.purchaseId] as String? : null) ?? '';
    super.onInit();
  }

  @override
  Future<({Purchase bill, List<SupplierPayment> payments})> fetch() async {
    final bill = await _purchases.byId(purchaseId);
    if (bill == null) {
      throw const AppException('This bill is no longer in your records.');
    }

    // Fetched separately rather than joined: a bill's payments are a short list
    // read only on this screen, and loading them with every list query would
    // cost every other screen for one.
    final payments = await _payments.list(purchaseId: purchaseId);

    return (bill: bill, payments: payments);
  }

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
