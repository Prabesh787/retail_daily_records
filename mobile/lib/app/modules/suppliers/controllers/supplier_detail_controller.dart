import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../routes/app_pages.dart';

/// Which slice of the ledger the detail screen is showing.
enum LedgerTab { ledger, bills, payments }

/// One supplier: what they are owed, and the movements that add up to it.
///
/// The screen exists to make the balance checkable by eye. The card states the
/// figure; the ledger underneath is the same arithmetic as a column of
/// movements, so a shopkeeper who distrusts the number can read the working.
class SupplierDetailController extends LoaderController<SupplierStatement> {
  final SupplierRepository _suppliers = Get.find<SupplierRepository>();

  late final String supplierId;

  final Rx<DateRange> range = const DateRange.all().obs;
  final RxString search = ''.obs;
  final Rx<LedgerTab> tab = LedgerTab.ledger.obs;

  @override
  List<String> get watches => const [
    DbTables.supplier,
    DbTables.purchase,
    DbTables.supplierPayment,
  ];

  SupplierStatement? get statement => data.value;

  /// True when the user has narrowed things — which is what decides whether the
  /// window figures are worth showing at all. Unfiltered, they would just
  /// restate the balance card above them.
  bool get isFiltered => !range.value.isAll || search.value.trim().isNotEmpty;

  @override
  void onInit() {
    final args = Get.arguments;
    supplierId = (args is Map ? args[RouteArgs.supplierId] as String? : null) ?? '';

    debounce<String>(
      search,
      (_) => load(silent: true),
      time: const Duration(milliseconds: 280),
    );
    super.onInit();
  }

  @override
  Future<SupplierStatement> fetch() async {
    final term = search.value.trim();
    final result = await _suppliers.statement(
      supplierId,
      fromMs: range.value.from,
      toMs: range.value.to,
      search: term.isEmpty ? null : term,
    );

    if (result == null) {
      throw const AppException('This supplier is no longer in your records.');
    }
    return result;
  }

  /// The rows for whichever tab is showing.
  ///
  /// The ledger tab interleaves both kinds; the other two are the same data
  /// filtered, not queried again — so switching tabs cannot change what the
  /// screen believes about this supplier.
  List<LedgerMovement> get visibleRows {
    final current = statement;
    if (current == null) return const [];

    return switch (tab.value) {
      LedgerTab.ledger => current.movements,
      LedgerTab.bills => current.movements.where((m) => m.isBill).toList(),
      LedgerTab.payments => current.movements.where((m) => !m.isBill).toList(),
    };
  }

  void setTab(LedgerTab value) => tab.value = value;

  void setRange(DateRange value) {
    range.value = value;
    load(silent: true);
  }

  void clearFilters() {
    search.value = '';
    range.value = const DateRange.all();
    load(silent: true);
  }

  void edit() => Get.toNamed<void>(
    Routes.supplierForm,
    arguments: {RouteArgs.supplierId: supplierId},
  );

  /// The report carries whatever window is on screen, so opening it does not
  /// silently drop the filter the user just set.
  void openStatement() => Get.toNamed<void>(
    Routes.supplierStatement,
    arguments: {
      RouteArgs.supplierId: supplierId,
      RouteArgs.fromMs: range.value.from,
      RouteArgs.toMs: range.value.to,
    },
  );

  void recordPayment() => Get.toNamed<void>(
    Routes.paymentForm,
    arguments: {RouteArgs.presetSupplierId: supplierId},
  );

  void openBill(String purchaseId) => Get.toNamed<void>(
    Routes.purchaseDetail,
    arguments: {RouteArgs.purchaseId: purchaseId},
  );

  void openPayment(String paymentId) => Get.toNamed<void>(
    Routes.paymentDetail,
    arguments: {RouteArgs.paymentId: paymentId},
  );
}

