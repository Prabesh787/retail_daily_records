import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/supplier_payment.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../routes/app_pages.dart';

/// One day's book.
///
/// The only screen that reads across all three ledgers at once, because the
/// question it answers — "how did today go" — is not a question about any one
/// of them. Watching all three is therefore correct rather than excessive: a
/// bill entered while this screen is open belongs on it.
class SaleDayController extends LoaderController<DayBook> {
  final SaleRepository _sales = Get.find<SaleRepository>();

  late final int dateMs;

  @override
  List<String> get watches => const [
    DbTables.sale,
    DbTables.purchase,
    DbTables.supplierPayment,
  ];

  DayBook? get book => data.value;

  @override
  void onInit() {
    final args = Get.arguments;
    final passed = args is Map ? args[RouteArgs.dateMs] as int? : null;

    // Defaults to today, so the route is a usable deep link on its own.
    dateMs = passed ?? AppDateUtils.startOfTodayMs();
    super.onInit();
  }

  @override
  Future<DayBook> fetch() => _sales.dayBookFull(dateMs);

  void openSale(Sale sale) => Get.toNamed<void>(
    Routes.saleDetail,
    arguments: {RouteArgs.saleId: sale.id},
  );

  void openPurchase(Purchase purchase) => Get.toNamed<void>(
    Routes.purchaseDetail,
    arguments: {RouteArgs.purchaseId: purchase.id},
  );

  void openPayment(SupplierPayment payment) => Get.toNamed<void>(
    Routes.paymentDetail,
    arguments: {RouteArgs.paymentId: payment.id},
  );
}
