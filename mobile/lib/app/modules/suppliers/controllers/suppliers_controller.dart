import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/domain/money.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../routes/app_pages.dart';

/// The suppliers list — a payables worklist ordered by what is owed, not an
/// address book ordered by name.
class SuppliersController extends LoaderController<List<Supplier>> {
  final SupplierRepository _suppliers = Get.find<SupplierRepository>();

  final RxString search = ''.obs;

  /// Balances are derived from bills and payments, so this list is stale the
  /// moment either of those is written — even though no supplier row moved.
  /// Watching only [DbTables.supplier] would leave every figure here wrong
  /// after a payment until the screen was rebuilt for some other reason.
  @override
  List<String> get watches => const [
    DbTables.supplier,
    DbTables.purchase,
    DbTables.supplierPayment,
  ];

  List<Supplier> get rows => data.value ?? const [];

  @override
  bool get isEmpty => rows.isEmpty;

  bool get isSearching => search.value.trim().isNotEmpty;

  @override
  void onInit() {
    // Typing filters the list, but not on every keystroke: each one is a
    // database query, and the shopkeeper is still typing.
    debounce<String>(
      search,
      (_) => load(silent: true),
      time: const Duration(milliseconds: 280),
    );
    super.onInit();
  }

  @override
  Future<List<Supplier>> fetch() {
    final term = search.value.trim();
    return _suppliers.list(search: term.isEmpty ? null : term);
  }

  /// The three figures on the card above the list, summed from the rows on
  /// screen rather than queried separately — so the total and the list it sits
  /// over can never disagree, including while a search is narrowing both.
  Money get totalOutstanding => Money.sum(
    rows.map((s) => s.balance?.outstanding ?? Money.zero).where((m) => m.isPositive),
  );

  Money get totalCleared =>
      Money.sum(rows.map((s) => s.balance?.clearedTotal ?? Money.zero));

  Money get totalUncleared =>
      Money.sum(rows.map((s) => s.balance?.uncleared ?? Money.zero));

  void onSearchChanged(String value) => search.value = value;

  void openSupplier(Supplier supplier) => Get.toNamed<void>(
    Routes.supplierDetail,
    arguments: {RouteArgs.supplierId: supplier.id},
  );

  void createSupplier() => Get.toNamed<void>(Routes.supplierForm);
}
