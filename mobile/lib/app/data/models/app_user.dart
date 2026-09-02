import '../dto/wire_codec.dart';

/// The signed-in account and the shop it trades as.
///
/// Not a synced entity and not a table: there is exactly one of these on a
/// device, it is whatever `GET /auth/me` last said, and it is cached in
/// key-value storage so the app can print a bill under the shop's name with no
/// network.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'USER',
    this.isActive = true,
    this.shop = const Shop(),
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final Shop shop;

  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'isActive': isActive,
        'shop': shop.toJson(),
      };

  /// Reads both shapes the API returns.
  ///
  /// `POST /auth/login` and `GET /auth/me` nest the account under `user` with
  /// `shop` repeated beside it; the locally cached copy is this class's own
  /// `toJson`. Accepting both means the cache and the wire can be read by the
  /// same code.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    final shop = json['shop'] is Map<String, dynamic>
        ? json['shop'] as Map<String, dynamic>
        : (user['shop'] is Map<String, dynamic>
            ? user['shop'] as Map<String, dynamic>
            : const <String, dynamic>{});

    return AppUser(
      id: WireCodec.string(user['id']),
      name: WireCodec.string(user['name']),
      email: WireCodec.string(user['email']),
      role: WireCodec.stringOrNull(user['role']) ?? 'USER',
      isActive: WireCodec.boolean(user['isActive'], fallback: true),
      shop: Shop.fromJson(shop),
    );
  }

  AppUser copyWith({String? name, Shop? shop}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role,
        isActive: isActive,
        shop: shop ?? this.shop,
      );
}

/// What is printed at the top of a bill.
class Shop {
  const Shop({this.name, this.address, this.phone, this.pan});

  final String? name;
  final String? address;
  final String? phone;
  final String? pan;

  bool get isSet => (name ?? '').trim().isNotEmpty;

  /// The address and PAN under the shop name, skipping whichever is missing — a
  /// shop with no PAN should read "Butwal-11, Rupandehi", not
  /// "Butwal-11, Rupandehi · PAN null".
  String get subtitle => [
        if ((address ?? '').trim().isNotEmpty) address!.trim(),
        if ((pan ?? '').trim().isNotEmpty) 'PAN ${pan!.trim()}',
      ].join(' · ');

  Map<String, dynamic> toJson() =>
      {'name': name, 'address': address, 'phone': phone, 'pan': pan};

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        name: WireCodec.stringOrNull(json['name']),
        address: WireCodec.stringOrNull(json['address']),
        phone: WireCodec.stringOrNull(json['phone']),
        pan: WireCodec.stringOrNull(json['pan']),
      );

  Shop copyWith({String? name, String? address, String? phone, String? pan}) =>
      Shop(
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        pan: pan ?? this.pan,
      );
}
