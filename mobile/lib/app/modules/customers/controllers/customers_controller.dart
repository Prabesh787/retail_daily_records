import 'package:get/get.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/controllers/loader_controller.dart';
import '../../../core/domain/money.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../routes/app_pages.dart';

/// The customers a shop actually keeps records for.
///
/// Not everyone who buys something — a walk-in paying cash is a sale with no
/// customer attached, and inventing a record for them would fill the list with
/// rows nobody ever looks at again. A customer here is someone the shop
/// invoices or extends credit to.
class CustomersController extends LoaderController<List<Customer>> {
  final CustomerRepository _customers = Get.find<CustomerRepository>();

  final RxString search = ''.obs;

  /// Sales are watched as well as customers: the totals shown against each name
  /// are derived from them, so a sale recorded elsewhere changes this list even
  /// though no customer row moved.
  @override
  List<String> get watches => const [DbTables.customer, DbTables.sale];

  List<Customer> get rows => data.value ?? const [];

  @override
  bool get isEmpty => rows.isEmpty;

  bool get isSearching => search.value.trim().isNotEmpty;

  Money get total => Money.sum(rows.map((c) => c.saleTotal ?? Money.zero));

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
  Future<List<Customer>> fetch() {
    final term = search.value.trim();
    return _customers.list(search: term.isEmpty ? null : term);
  }

  void openCustomer(Customer customer) => Get.toNamed<void>(
    Routes.customerForm,
    arguments: {RouteArgs.customerId: customer.id},
  );

  void createCustomer() => Get.toNamed<void>(Routes.customerForm);
}
