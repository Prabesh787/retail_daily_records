import 'package:get/get.dart';

import '../data/providers/remote/api_client.dart';
import '../data/providers/remote/rest_sync_api.dart';
import '../data/providers/remote/sync_api.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/fiscal_year_repository.dart';
import '../data/repositories/purchase_repository.dart';
import '../data/repositories/sale_repository.dart';
import '../data/repositories/supplier_payment_repository.dart';
import '../data/repositories/supplier_repository.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Global dependencies: the HTTP client and the backend adapter.
///
/// Only things every screen may need live here. Screen controllers belong to
/// their own module binding so they can be disposed with their route.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SyncApi>(_buildSyncApi, fenix: true);

    // Repositories are stateless wrappers over the DAOs, so `fenix` lets them
    // be recreated on demand after a route disposes them.
    Get.lazyPut<FiscalYearRepository>(FiscalYearRepository.new, fenix: true);
    Get.lazyPut<SupplierRepository>(SupplierRepository.new, fenix: true);
    Get.lazyPut<CustomerRepository>(CustomerRepository.new, fenix: true);
    Get.lazyPut<PurchaseRepository>(PurchaseRepository.new, fenix: true);
    Get.lazyPut<SupplierPaymentRepository>(
      SupplierPaymentRepository.new,
      fenix: true,
    );
    Get.lazyPut<SaleRepository>(SaleRepository.new, fenix: true);
  }

  /// One HTTP client, shared by auth and sync.
  ///
  /// Shared rather than one each, so a token cleared by a 401 on either path is
  /// gone for both immediately - `tokenProvider` is read per request.
  ///
  /// The `Get.isRegistered` guard breaks a real cycle: the client is built
  /// before AuthService exists (the service needs the client), and the first
  /// request cannot happen until both are up. A closure resolves it at call
  /// time rather than at construction.
  ///
  /// `API_BASE_URL` should include the version prefix, e.g.
  /// `http://10.0.2.2:4000/api/v1` - every path below is relative to it.
  static ApiClient buildApiClient() {
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    return ApiClient(
      baseUrl: baseUrl,
      tokenProvider: () =>
          Get.isRegistered<AuthService>() ? AuthService.to.token : null,
      onUnauthorized: () {
        if (Get.isRegistered<AuthService>()) AuthService.to.onUnauthorized();
      },
    );
  }

  /// The single line that changes when the backend is pointed at.
  ///
  /// With no base URL the app runs local-only and says so; set `API_BASE_URL`
  /// and the same build starts syncing.
  static SyncApi _buildSyncApi() {
    final client = Get.find<ApiClient>();
    if (!client.isConfigured) return const NoopSyncApi();

    return RestSyncApi(client, deviceId: Get.find<StorageService>().deviceId);
  }
}
