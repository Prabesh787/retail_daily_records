import '../../core/domain/money.dart';
import '../dto/wire_codec.dart';

/// One free-text line on an itemised invoice.
///
/// It is **not** an inventory record and points at no product table: there is
/// no item master in this system. "Printed Cotton - Blue, 5 METER, Rs. 800" is
/// a description of what was written on a piece of paper, nothing more.
class SaleItem {
  const SaleItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.unit = 'PCS',
    this.discount = Money.zero,
    this.createdAt = 0,
  });

  /// Empty on a line the form has built. The server assigns it — invoice lines
  /// are created with their sale and never addressed on their own.
  final String id;

  final String description;
  final Quantity quantity;
  final String unit;
  final Money unitPrice;
  final Money discount;

  final int createdAt;

  /// Always recomputed, never read back from a stored value — the one place a
  /// line amount is produced, matching the backend's `calculateLineAmount`, so
  /// a line previewed on the form and the same line read back after saving
  /// cannot round differently.
  Money get amount =>
      calculateLineAmount(quantity, unitPrice, discount: discount);

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        id: WireCodec.string(json['id']),
        description: WireCodec.string(json['description']),
        quantity: WireCodec.quantity(json['quantity']),
        unit: WireCodec.stringOrNull(json['unit']) ?? 'PCS',
        unitPrice: WireCodec.money(json['unitPrice']),
        discount: WireCodec.money(json['discount']),
        createdAt: WireCodec.millis(json['createdAt'], fallback: 0),
      );

  /// The line as `POST /sales` accepts it.
  ///
  /// No `amount` and no `id`: the server computes the first and assigns the
  /// second, and sending either would be the client claiming authority over a
  /// value it does not own.
  Map<String, dynamic> toRequestBody() => {
        'description': description,
        'quantity': quantity.toWire(),
        'unit': unit,
        'unitPrice': unitPrice.toWire(),
        'discount': discount.toWire(),
      };

  SaleItem copyWith({
    String? id,
    String? description,
    Quantity? quantity,
    String? unit,
    Money? unitPrice,
    Money? discount,
  }) =>
      SaleItem(
        id: id ?? this.id,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        unitPrice: unitPrice ?? this.unitPrice,
        discount: discount ?? this.discount,
        createdAt: createdAt,
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
}
