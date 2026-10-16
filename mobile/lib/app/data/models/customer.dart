import '../../core/domain/money.dart';
import '../dto/wire_codec.dart';

/// Someone a sale was invoiced to.
///
/// Optional by design: a walk-in sale carries no customer at all, and most do
/// not. A customer record exists because someone asked for a proper invoice,
/// not because the shop keeps a directory.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.pan,
    this.remarks,
    this.saleCount,
    this.saleTotal,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  /// Empty on a draft the form has built and the server has not seen yet.
  final String id;

  final String name;
  final String? phone;
  final String? address;
  final String? pan;
  final String? remarks;

  /// Derived by the server from the customer's sales.
  ///
  /// Null means the payload did not carry them, which is different from zero: a
  /// screen without the figures should show nothing rather than claim the
  /// customer has never bought anything.
  final int? saleCount;
  final Money? saleTotal;

  final int createdAt;
  final int updatedAt;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: WireCodec.string(json['id']),
        name: WireCodec.string(json['name']),
        phone: WireCodec.stringOrNull(json['phone']),
        address: WireCodec.stringOrNull(json['address']),
        pan: WireCodec.stringOrNull(json['pan']),
        remarks: WireCodec.stringOrNull(json['remarks']),
        saleCount: json.containsKey('saleCount')
            ? WireCodec.integer(json['saleCount'])
            : null,
        saleTotal: json.containsKey('saleTotal')
            ? WireCodec.money(json['saleTotal'])
            : null,
        createdAt: WireCodec.millis(json['createdAt'], fallback: 0),
        updatedAt: WireCodec.millis(json['updatedAt'], fallback: 0),
      );

  /// The body `POST /customers` and `PATCH /customers/:id` accept.
  Map<String, dynamic> toRequestBody() => {
        'name': name,
        'phone': phone,
        'address': address,
        'pan': pan,
        'remarks': remarks,
      };

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? pan,
    String? remarks,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        pan: pan ?? this.pan,
        remarks: remarks ?? this.remarks,
        saleCount: saleCount,
        saleTotal: saleTotal,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
