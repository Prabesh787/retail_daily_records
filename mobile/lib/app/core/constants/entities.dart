/// The names the app calls the things it stores.
///
/// One vocabulary, used for three jobs: the path segment each entity lives
/// under on the API, the key a screen watches for changes under, and the label
/// in an error message. Keeping them in one place means a rename is a single
/// edit rather than a grep across the data layer.
class Entities {
  Entities._();

  static const String fiscalYear = 'fiscal-years';
  static const String supplier = 'suppliers';
  static const String customer = 'customers';
  static const String purchase = 'purchases';
  static const String supplierPayment = 'supplier-payments';
  static const String sale = 'sales';
}

/// Keys in the on-device key-value store.
///
/// There is very little here by design. The shop's records live on the server;
/// what stays on the phone is the session and the handful of preferences that
/// are about this device rather than about the business.
class StorageKeys {
  StorageKeys._();

  static const String currencySymbol = 'currency_symbol';
  static const String themeMode = 'theme_mode';

  /// The bearer token, and the account `GET /auth/me` last returned.
  ///
  /// The cached account is a convenience only — it lets the shop's name appear
  /// on the first frame instead of after a round trip — and it is re-read from
  /// the server on every launch.
  ///
  /// `get_storage` writes plaintext, which is acceptable for a shop-floor
  /// device holding little else. Moving the token to `flutter_secure_storage`
  /// is a contained change: [AuthService] is the only reader.
  static const String authToken = 'auth_token';
  static const String cachedUser = 'cached_user';
}
