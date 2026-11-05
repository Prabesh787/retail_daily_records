import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/widgets/domain/date_range_sheet.dart';
import '../../../data/models/ledger.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../routes/app_pages.dart';

/// The History tab: everything the shop recorded, newest first, whichever
/// kind of document it is.
class ActivityController extends LoaderController<List<ActivityItem>> {
  final ActivityRepository _activity = Get.find<ActivityRepository>();

  /// Enough for a phone to scroll comfortably. Older records are one search or
  /// date filter away.
  static const int pageLimit = 300;

  final RxString search = ''.obs;
  final Rxn<ActivityKind> kind = Rxn<ActivityKind>();
  final Rx<DateRange> range = const DateRange.all().obs;

  @override
  List<String> get watches => const [
    DbTables.sale,
    DbTables.purchase,
    DbTables.customerPayment,
    DbTables.supplierPayment,
    DbTables.customer,
    DbTables.supplier,
  ];

  List<ActivityItem> get rows => data.value ?? const [];

  @override
  bool get isEmpty => rows.isEmpty;

  bool get isFiltered =>
      search.value.trim().isNotEmpty || kind.value != null || !range.value.isAll;

  bool get isAtLimit => rows.length >= pageLimit;

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
  Future<List<ActivityItem>> fetch() => _activity.feed(
    kind: kind.value,
    search: search.value.trim().isEmpty ? null : search.value.trim(),
    fromMs: range.value.from,
    toMs: range.value.to,
    limit: pageLimit,
  );

  void setKind(ActivityKind? value) {
    kind.value = value;
    load(silent: true);
  }

  void setRange(DateRange value) {
    range.value = value;
    load(silent: true);
  }

  void clearFilters() {
    search.value = '';
    kind.value = null;
    range.value = const DateRange.all();
    load(silent: true);
  }

  void open(ActivityItem item) {
    switch (item.kind) {
      case ActivityKind.sale:
        Get.toNamed<void>(
          Routes.saleDetail,
          arguments: {RouteArgs.saleId: item.id},
        );
      case ActivityKind.purchase:
        Get.toNamed<void>(
          Routes.purchaseDetail,
          arguments: {RouteArgs.purchaseId: item.id},
        );
      case ActivityKind.paymentIn:
        Get.toNamed<void>(
          Routes.receiptDetail,
          arguments: {RouteArgs.paymentId: item.id},
        );
      case ActivityKind.paymentOut:
        Get.toNamed<void>(
          Routes.paymentDetail,
          arguments: {RouteArgs.paymentId: item.id},
        );
    }
  }
}
