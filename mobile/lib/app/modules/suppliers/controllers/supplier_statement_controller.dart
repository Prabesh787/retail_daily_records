import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/domain/domain_widgets.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../routes/app_pages.dart';

/// A supplier statement for one date window.
///
/// The same query the detail screen runs, drawn as a document: the position
/// carried in, every movement in order, and the position carried out. That is
/// the form a supplier will actually reconcile against.
class SupplierStatementController extends LoaderController<SupplierStatement> {
  final SupplierRepository _suppliers = Get.find<SupplierRepository>();

  late final String supplierId;

  final Rx<DateRange> range = const DateRange.all().obs;

  @override
  List<String> get watches => const [
    DbTables.supplier,
    DbTables.purchase,
    DbTables.supplierPayment,
  ];

  SupplierStatement? get statement => data.value;

  @override
  void onInit() {
    final args = Get.arguments is Map
        ? Get.arguments as Map<dynamic, dynamic>
        : const {};

    supplierId = (args[RouteArgs.supplierId] as String?) ?? '';

    // Opened from the detail screen, which passes whatever window was showing.
    // Arriving with a different range than the one just being read would look
    // like the report disagreeing with the screen that launched it.
    range.value = DateRange(
      from: args[RouteArgs.fromMs] as int?,
      to: args[RouteArgs.toMs] as int?,
    );

    super.onInit();
  }

  @override
  Future<SupplierStatement> fetch() async {
    final result = await _suppliers.statement(
      supplierId,
      fromMs: range.value.from,
      toMs: range.value.to,
    );

    if (result == null) {
      throw const AppException('This supplier is no longer in your records.');
    }
    return result;
  }

  void setRange(DateRange value) {
    range.value = value;
    load(silent: true);
  }
}
