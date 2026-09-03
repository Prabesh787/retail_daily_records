import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/domain/day_group.dart';
import '../../../core/domain/money.dart';
import '../../../data/models/purchase.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../../routes/app_pages.dart';

/// Bills in, newest first, grouped by the day they were entered.
class PurchasesController extends LoaderController<List<Purchase>> {
  final PurchaseRepository _purchases = Get.find<PurchaseRepository>();

  final RxString search = ''.obs;
  final RxBool onlyUnpaid = false.obs;

  /// Payments are watched as well as purchases: a bill's paid total is derived,
  /// so recording a payment changes what this list says about a bill even
  /// though the bill itself was not touched.
  @override
  List<String> get watches => const [
    DbTables.purchase,
    DbTables.supplierPayment,
  ];

  List<Purchase> get rows => data.value ?? const [];

  @override
  bool get isEmpty => rows.isEmpty;

  bool get isFiltered => search.value.trim().isNotEmpty || onlyUnpaid.value;

  /// The day buckets the list is drawn from. The DAO returns bills newest
  /// first, and the grouping preserves that order.
  List<DayGroup<Purchase>> get groups =>
      groupByDay(rows, (p) => p.billDate, (p) => p.amount);

  Money get total => Money.sum(rows.map((p) => p.amount));

  @override
  void onInit() {
    debounce<String>(
      search,
      (_) => load(silent: true),
      time: const Duration(milliseconds: 280),
    );
    super.onInit();
  }

  @override
  Future<List<Purchase>> fetch() {
    final term = search.value.trim();
    return _purchases.list(
      search: term.isEmpty ? null : term,
      onlyUnpaid: onlyUnpaid.value,
      limit: 200,
    );
  }

  void setOnlyUnpaid(bool value) {
    onlyUnpaid.value = value;
    load(silent: true);
  }

  void clearFilters() {
    search.value = '';
    onlyUnpaid.value = false;
    load(silent: true);
  }

  void openBill(Purchase purchase) => Get.toNamed<void>(
    Routes.purchaseDetail,
    arguments: {RouteArgs.purchaseId: purchase.id},
  );

  void createBill() => Get.toNamed<void>(Routes.purchaseForm);
}
