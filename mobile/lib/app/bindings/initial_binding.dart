import 'package:get/get.dart';

import '../data/providers/remote/api_client.dart';
import '../data/providers/remote/retail_api.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/fiscal_year_repository.dart';
import '../data/repositories/purchase_repository.dart';
import '../data/repositories/sale_repository.dart';
import '../data/repositories/supplier_payment_repository.dart';
import '../data/repositories/supplier_repository.dart';
import '../services/auth_service.dart';

/// Global dependencies: the API surface and the repositories over it.
///
/// Only things every screen may need live here. Screen controllers belong to
/// their own module binding so they can be disposed with their route.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RetailApi>(
      () => RetailApi(Get.find<ApiClient>()),
      fenix: true,
    );

    // Repositories are stateless wrappers over the API, so `fenix` lets them be
    // recreated on demand after a route disposes them.
    Get.lazyPut<FiscalYearRepository>(FiscalYearRepository.new, fenix: true);
    Get.lazyPut<SupplierRepository>(SupplierRepository.new, fenix: true);
    Get.lazyPut<CustomerRepository>(CustomerRepository.new, fenix: true);
    Get.lazyPut<PurchaseRepository>(PurchaseRepository.new, fenix: true);
    Get.lazyPut<SupplierPaymentRepository>(
      SupplierPaymentRepository.new,
      fenix: true,
    );
    Get.lazyPut<SaleRepository>(SaleRepository.new, fenix: true);

    // Reads one report rather than owning an entity of its own; registered here
    // so the dashboard binding has nothing to build but its controller.
    Get.lazyPut<DashboardRepository>(DashboardRepository.new, fenix: true);
  }

  /// Where the app looks for its records.
  ///
  /// `API_BASE_URL` includes the version prefix — every path in [RetailApi] is
  /// relative to it. The default is the Android emulator's route to a backend
  /// running on the development machine, so `flutter run` works out of the box
  /// the way `npm run dev` does for the web app; a real build points it
  /// somewhere real:
  ///
  ///     flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000/api/v1',
  );

  /// One HTTP client for the whole app.
  ///
  /// Shared rather than one per feature, so a token cleared by a 401 anywhere
  /// is gone everywhere immediately — `tokenProvider` is read per request.
  ///
  /// The `Get.isRegistered` guard breaks a real cycle: the client is built
  /// before AuthService exists (the service is built on the client), and the
  /// first request cannot happen until both are up. A closure resolves it at
  /// call time rather than at construction.
  static ApiClient buildApiClient() => ApiClient(
        baseUrl: baseUrl,
        tokenProvider: () =>
            Get.isRegistered<AuthService>() ? AuthService.to.token : null,
        onUnauthorized: () {
          if (Get.isRegistered<AuthService>()) AuthService.to.onUnauthorized();
        },
      );
}
