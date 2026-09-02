/// Table and shared column names. Keeping these in one place means a rename is
/// a single edit rather than a grep across every DAO.
class DbTables {
  DbTables._();

  // The retail shop model, mirroring the Postgres tables the web app uses, so
  // an entity name is also a wire name and a pull-cursor key. Each is created
  // as its model is built.

  static const String fiscalYear = 'fiscal_years';
  static const String supplier = 'suppliers';
  static const String customer = 'customers';
  static const String purchase = 'purchases';
  static const String supplierPayment = 'supplier_payments';
  static const String sale = 'sales';

  /// Children that travel inside their parent's payload rather than syncing on
  /// their own — a sale header that arrived without its lines would be an
  /// accounting error, not a partial success.
  static const String saleItem = 'sale_items';
  static const String salePayment = 'sale_payments';

  static const String syncQueue = 'sync_queue';

  /// Tables the sync engine walks, and the keys its pull cursors are stored
  /// under. Dependency order, parents first: a purchase references a fiscal
  /// year and a supplier, and a sale references a customer, so a child can
  /// never land before the row it belongs to.
  ///
  /// Entities join this list as their DAO, DTO and syncer are built.
  static const List<String> syncable = [
    fiscalYear,
    supplier,
    customer,
    purchase,
    supplierPayment,
    sale,
  ];
}

/// Columns every syncable table carries. See [SyncableModel].
class SyncColumns {
  SyncColumns._();

  static const String id = 'id';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String isDeleted = 'is_deleted';
  static const String syncStatus = 'sync_status';
  static const String deviceId = 'device_id';

  /// Appended to every CREATE TABLE for a syncable entity.
  static const String definition = '''
    $createdAt   INTEGER NOT NULL,
    $updatedAt   INTEGER NOT NULL,
    $isDeleted   INTEGER NOT NULL DEFAULT 0,
    $syncStatus  INTEGER NOT NULL DEFAULT 0,
    $deviceId    TEXT
  ''';
}

class StorageKeys {
  StorageKeys._();

  static const String deviceId = 'device_id';
  static const String shopName = 'shop_name';
  static const String shopPhone = 'shop_phone';
  static const String shopAddress = 'shop_address';
  static const String currencySymbol = 'currency_symbol';
  static const String themeMode = 'theme_mode';
  static const String lastSyncedAt = 'last_synced_at';
  static const String syncEnabled = 'sync_enabled';

  /// The bearer token, and the account `GET /auth/me` last returned.
  ///
  /// `get_storage` writes plaintext, which is acceptable for a shop-floor
  /// device holding its own records and not much else. Moving the token to
  /// `flutter_secure_storage` is a contained change — only [AuthService] reads
  /// it — and worth doing before this goes to anyone else.
  static const String authToken = 'auth_token';
  static const String cachedUser = 'cached_user';

  /// Per-entity pull cursor, e.g. `cursor_bills`.
  static String cursor(String entity) => 'cursor_$entity';
}
