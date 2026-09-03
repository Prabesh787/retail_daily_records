import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/domain/day_group.dart';
import '../../../core/domain/money.dart';
import '../../../data/enums/sale_type.dart';
import '../../../data/models/sale.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../routes/app_pages.dart';

/// Sales, newest first, grouped by the day they were made.
class SalesController extends LoaderController<List<Sale>> {
  final SaleRepository _sales = Get.find<SaleRepository>();

  final RxString search = ''.obs;
  final Rxn<SaleType> typeFilter = Rxn<SaleType>();

  @override
  List<String> get watches => const [DbTables.sale];

  List<Sale> get rows => data.value ?? const [];

  @override
  bool get isEmpty => rows.isEmpty;

  bool get isFiltered =>
      search.value.trim().isNotEmpty || typeFilter.value != null;

  List<DayGroup<Sale>> get groups =>
      groupByDay(rows, (s) => s.saleDate, (s) => s.totalAmount);

  /// Turnover across the rows on screen — what was sold, credit included.
  Money get total => Money.sum(rows.map((s) => s.totalAmount));

  /// What was actually taken. Reported next to [total] rather than instead of
  /// it: a day that sold well on credit is a good day and a bad till, and the
  /// list should not have to choose which of those to say.
  Money get received => Money.sum(rows.map((s) => s.settledTotal));

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
  Future<List<Sale>> fetch() {
    final term = search.value.trim();
    return _sales.list(
      search: term.isEmpty ? null : term,
      saleType: typeFilter.value,
      limit: 200,
    );
  }

  void setTypeFilter(SaleType? value) {
    typeFilter.value = value;
    load(silent: true);
  }

  void clearFilters() {
    search.value = '';
    typeFilter.value = null;
    load(silent: true);
  }

  void openSale(Sale sale) => Get.toNamed<void>(
    Routes.saleDetail,
    arguments: {RouteArgs.saleId: sale.id},
  );

  /// The day header opens the whole day — takings, how they were settled, and
  /// the money that went out the same day.
  void openDay(int dateMs) => Get.toNamed<void>(
    Routes.saleDay,
    arguments: {RouteArgs.dateMs: dateMs},
  );

  void createSale() => Get.toNamed<void>(Routes.saleForm);
}
