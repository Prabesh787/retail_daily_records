import '../../../core/constants/entities.dart';
import 'api_client.dart';

/// Every endpoint the app calls, in one place.
///
/// This is the mobile counterpart of the web app's `lib/api/index.js`, and the
/// resemblance is the point: two clients against one API drift apart the moment
/// each writes its own paths, and the drift is invisible until a field is
/// renamed on one side only.
///
/// Nothing here interprets a payload — that is the models' job. What lives here
/// is the path, the verb, and the shape of the query string, so a repository
/// asks for "this supplier's ledger between these dates" and never assembles a
/// URL.
///
/// Every endpoint except `/auth/login` and `/health` needs a bearer token;
/// [ApiClient] attaches it, so nothing below has to think about it.
class RetailApi {
  const RetailApi(this._client);

  final ApiClient _client;

  bool get isConfigured => _client.isConfigured;

  // ---- Fiscal years -------------------------------------------------------

  Future<ApiResponse> fiscalYears() => _client.get('/${Entities.fiscalYear}');

  Future<ApiResponse> activeFiscalYear() =>
      _client.get('/${Entities.fiscalYear}/active');

  Future<ApiResponse> createFiscalYear(Map<String, dynamic> body) =>
      _client.post('/${Entities.fiscalYear}', body: body);

  Future<ApiResponse> updateFiscalYear(String id, Map<String, dynamic> body) =>
      _client.patch('/${Entities.fiscalYear}/$id', body: body);

  Future<ApiResponse> activateFiscalYear(String id) =>
      _client.post('/${Entities.fiscalYear}/$id/activate');

  Future<ApiResponse> deleteFiscalYear(String id) =>
      _client.delete('/${Entities.fiscalYear}/$id');

  // ---- Suppliers ----------------------------------------------------------

  Future<ApiResponse> suppliers({Map<String, dynamic>? query}) =>
      _client.get('/${Entities.supplier}', query: query);

  /// The supplier, their all-time balance, and the ledger for one date window.
  ///
  /// One call for the detail screen and the statement both, because they ask
  /// the same question and differ only in how they draw the answer.
  Future<ApiResponse> supplier(String id, {Map<String, dynamic>? query}) =>
      _client.get('/${Entities.supplier}/$id', query: query);

  Future<ApiResponse> createSupplier(Map<String, dynamic> body) =>
      _client.post('/${Entities.supplier}', body: body);

  Future<ApiResponse> updateSupplier(String id, Map<String, dynamic> body) =>
      _client.patch('/${Entities.supplier}/$id', body: body);

  Future<ApiResponse> deleteSupplier(String id) =>
      _client.delete('/${Entities.supplier}/$id');

  // ---- Customers ----------------------------------------------------------

  Future<ApiResponse> customers({Map<String, dynamic>? query}) =>
      _client.get('/${Entities.customer}', query: query);

  Future<ApiResponse> customer(String id) =>
      _client.get('/${Entities.customer}/$id');

  Future<ApiResponse> createCustomer(Map<String, dynamic> body) =>
      _client.post('/${Entities.customer}', body: body);

  Future<ApiResponse> updateCustomer(String id, Map<String, dynamic> body) =>
      _client.patch('/${Entities.customer}/$id', body: body);

  Future<ApiResponse> deleteCustomer(String id) =>
      _client.delete('/${Entities.customer}/$id');

  // ---- Purchases ----------------------------------------------------------

  Future<ApiResponse> purchases({Map<String, dynamic>? query}) =>
      _client.get('/${Entities.purchase}', query: query);

  Future<ApiResponse> purchase(String id) =>
      _client.get('/${Entities.purchase}/$id');

  Future<ApiResponse> createPurchase(Map<String, dynamic> body) =>
      _client.post('/${Entities.purchase}', body: body);

  Future<ApiResponse> updatePurchase(String id, Map<String, dynamic> body) =>
      _client.patch('/${Entities.purchase}/$id', body: body);

  Future<ApiResponse> deletePurchase(String id) =>
      _client.delete('/${Entities.purchase}/$id');

  // ---- Supplier payments --------------------------------------------------

  Future<ApiResponse> payments({Map<String, dynamic>? query}) =>
      _client.get('/${Entities.supplierPayment}', query: query);

  /// Cheques in the order the money has to be in the bank — by the date written
  /// on them, not the day they were handed over.
  Future<ApiResponse> chequeRegister({Map<String, dynamic>? query}) =>
      _client.get('/${Entities.supplierPayment}/cheque-register', query: query);

  Future<ApiResponse> payment(String id) =>
      _client.get('/${Entities.supplierPayment}/$id');

  Future<ApiResponse> createPayment(Map<String, dynamic> body) =>
      _client.post('/${Entities.supplierPayment}', body: body);

  Future<ApiResponse> clearPayment(String id, Map<String, dynamic> body) =>
      _client.post('/${Entities.supplierPayment}/$id/clear', body: body);

  Future<ApiResponse> cancelPayment(String id) =>
      _client.post('/${Entities.supplierPayment}/$id/cancel');

  Future<ApiResponse> deletePayment(String id) =>
      _client.delete('/${Entities.supplierPayment}/$id');

  // ---- Sales --------------------------------------------------------------

  Future<ApiResponse> sales({Map<String, dynamic>? query}) =>
      _client.get('/${Entities.sale}', query: query);

  Future<ApiResponse> sale(String id) => _client.get('/${Entities.sale}/$id');

  /// Everything recorded on one date: the takings, the bills taken on, and the
  /// suppliers paid. Three ledgers, one round trip.
  Future<ApiResponse> dayBook(String date) =>
      _client.get('/${Entities.sale}/day-book', query: {'date': date});

  Future<ApiResponse> createSale(Map<String, dynamic> body) =>
      _client.post('/${Entities.sale}', body: body);

  Future<ApiResponse> deleteSale(String id) =>
      _client.delete('/${Entities.sale}/$id');

  // ---- Reports ------------------------------------------------------------

  Future<ApiResponse> dashboard({Map<String, dynamic>? query}) =>
      _client.get('/reports/dashboard', query: query);

  Future<ApiResponse> supplierOutstanding({Map<String, dynamic>? query}) =>
      _client.get('/reports/supplier-outstanding', query: query);
}
