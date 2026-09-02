import '../../core/constants/db_constants.dart';
import '../../core/domain/money.dart';
import 'base/syncable_model.dart';

/// One free-text line on an itemised invoice.
///
/// It is **not** an inventory record and points at no product table: there is
/// no item master in this system. "Printed Cotton - Blue, 5 METER, Rs. 800" is
/// a description of what was written on a piece of paper, nothing more.
///
/// Items are not synced independently — they travel inside their sale's
/// payload. A half-applied sale (header arrived, three of five lines did not)
/// would show a total that does not match its own rows.
class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.unit = 'PCS',
    this.discount = Money.zero,
    this.sortOrder = 0,
    this.createdAt = 0,
  });

  final String id;
  final String saleId;
  final String description;
  final Quantity quantity;
  final String unit;
  final Money unitPrice;
  final Money discount;

  /// The order the lines were written on the invoice.
  ///
  /// Not in the server's schema yet. Without a column to sort on, line order is
  /// whatever the database happens to return, and an invoice whose lines
  /// reshuffle after a sync looks wrong to the person who wrote it.
  final int sortOrder;

  final int createdAt;

  /// Always recomputed, never read back from a stored value — the one place a
  /// line amount is produced, matching the backend's `calculateLineAmount`.
  Money get amount =>
      calculateLineAmount(quantity, unitPrice, discount: discount);

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'description': description,
        'quantity': quantity.toColumn(),
        'unit': unit,
        'unit_price': unitPrice.toColumn(),
        'discount': discount.toColumn(),
        // Denormalised so report queries can SUM it instead of reimplementing
        // the rounding rule in SQL. Written from [amount], never read into it.
        'amount': amount.toColumn(),
        'sort_order': sortOrder,
        'created_at': createdAt,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'saleId': saleId,
        'description': description,
        'quantity': quantity.toWire(),
        'unit': unit,
        'unitPrice': unitPrice.toWire(),
        'discount': discount.toWire(),
        'amount': amount.toWire(),
        'sortOrder': sortOrder,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        id: (map['id'] as String?) ?? '',
        saleId: (map['sale_id'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        quantity: Quantity.fromColumn(map['quantity']),
        unit: (map['unit'] as String?) ?? 'PCS',
        unitPrice: Money.fromColumn(map['unit_price']),
        discount: Money.fromColumn(map['discount']),
        sortOrder: SyncableModel.toInt(map['sort_order']),
        createdAt: SyncableModel.toInt(map['created_at']),
      );

  SaleItem copyWith({
    String? saleId,
    String? description,
    Quantity? quantity,
    String? unit,
    Money? unitPrice,
    Money? discount,
    int? sortOrder,
    int? createdAt,
  }) =>
      SaleItem(
        id: id,
        saleId: saleId ?? this.saleId,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        unitPrice: unitPrice ?? this.unitPrice,
        discount: discount ?? this.discount,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Units offered on the form. Free text is still allowed — mirrors
  /// `SALE_UNITS` in the web frontend.
  static const List<String> units = [
    'PCS',
    'METER',
    'SET',
    'PAIR',
    'DOZEN',
    'KG',
  ];

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.saleItem} (
      id          TEXT PRIMARY KEY,
      sale_id     TEXT NOT NULL,
      description TEXT NOT NULL,
      quantity    INTEGER NOT NULL DEFAULT 0,
      unit        TEXT NOT NULL DEFAULT 'PCS',
      unit_price  INTEGER NOT NULL DEFAULT 0,
      discount    INTEGER NOT NULL DEFAULT 0,
      amount      INTEGER NOT NULL DEFAULT 0,
      sort_order  INTEGER NOT NULL DEFAULT 0,
      created_at  INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (sale_id) REFERENCES ${DbTables.sale} (id) ON DELETE CASCADE
    )
  ''';
}
