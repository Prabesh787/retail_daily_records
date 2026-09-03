part of 'app_pages.dart';

/// Route names. Kept as constants so a typo is a compile error rather than a
/// blank screen at runtime.
///
/// The addresses mirror the web app's route table, so a screen is at the same
/// path in both.
abstract class Routes {
  Routes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';

  static const String suppliers = '/suppliers';
  static const String supplierForm = '/suppliers/form';
  static const String supplierDetail = '/suppliers/detail';
  static const String supplierStatement = '/suppliers/statement';

  static const String customers = '/customers';
  static const String customerForm = '/customers/form';

  static const String purchases = '/purchases';
  static const String purchaseForm = '/purchases/form';
  static const String purchaseDetail = '/purchases/detail';

  static const String sales = '/sales';
  static const String saleForm = '/sales/form';
  static const String saleDetail = '/sales/detail';
  static const String saleDay = '/sales/day';

  static const String cheques = '/cheques';
  static const String paymentForm = '/payments/form';
  static const String paymentDetail = '/payments/detail';

  static const String settings = '/settings';
  static const String fiscalYears = '/fiscal-years';
  static const String fiscalYearForm = '/fiscal-years/form';
  static const String shop = '/shop';
}

/// Keys for arguments passed between routes, so the sender and the receiver
/// cannot disagree about the spelling.
abstract class RouteArgs {
  RouteArgs._();

  static const String supplierId = 'supplier_id';
  static const String customerId = 'customer_id';
  static const String purchaseId = 'purchase_id';
  static const String saleId = 'sale_id';
  static const String paymentId = 'payment_id';
  static const String fiscalYearId = 'fiscal_year_id';

  /// A day, as epoch millis at UTC midnight - the day book's argument.
  static const String dateMs = 'date_ms';

  /// A date window, as epoch millis. The statement carries whatever range the
  /// detail screen was showing, so opening the report does not lose the filter
  /// the user just set.
  static const String fromMs = 'from_ms';
  static const String toMs = 'to_ms';

  /// Pre-selects a supplier or a bill when a form is opened from one.
  static const String presetSupplierId = 'preset_supplier_id';
  static const String presetCustomerId = 'preset_customer_id';
  static const String presetPurchaseId = 'preset_purchase_id';
}
