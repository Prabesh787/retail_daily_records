import '../../core/domain/money.dart';
import '../dto/wire_codec.dart';

/// A wholesale vendor the shop buys from.
///
/// Separate from `Customer` rather than sharing one "party" table: a supplier
/// carries an opening balance and a PAN and is the subject of the one
/// calculation this whole system exists for, while a customer is optional on a
/// sale and carries none of that.
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.pan,
    this.openingBalance = Money.zero,
    this.isActive = true,
    this.remarks,
    this.balance,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  /// Empty on a draft the form has built and the server has not seen yet.
  final String id;

  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? pan;

  /// What was owed on the day the shop started using the app. An input to the
  /// derived outstanding figure, never a running total.
  final Money openingBalance;

  final bool isActive;
  final String? remarks;

  /// Derived by the server from the bills and payments, and attached to every
  /// read of a supplier — never a stored column, here or there.
  ///
  /// Null means "not asked for", which is different from "zero": a screen that
  /// did not get the figure should show nothing rather than claim the supplier
  /// is settled.
  final SupplierBalance? balance;

  final int createdAt;
  final int updatedAt;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: WireCodec.string(json['id']),
        name: WireCodec.string(json['name']),
        contactPerson: WireCodec.stringOrNull(json['contactPerson']),
        phone: WireCodec.stringOrNull(json['phone']),
        email: WireCodec.stringOrNull(json['email']),
        address: WireCodec.stringOrNull(json['address']),
        pan: WireCodec.stringOrNull(json['pan']),
        openingBalance: WireCodec.money(json['openingBalance']),
        isActive: WireCodec.boolean(json['isActive'], fallback: true),
        remarks: WireCodec.stringOrNull(json['remarks']),
        balance: SupplierBalance.fromJson(json['balance']),
        createdAt: WireCodec.millis(json['createdAt'], fallback: 0),
        updatedAt: WireCodec.millis(json['updatedAt'], fallback: 0),
      );

  /// The body `POST /suppliers` and `PATCH /suppliers/:id` accept.
  ///
  /// `isActive` is only on the update schema, so it is sent only when this is
  /// an edit — a create that includes it is refused as an unknown field.
  Map<String, dynamic> toRequestBody({bool includeIsActive = false}) => {
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'pan': pan,
        'openingBalance': openingBalance.toWire(),
        'remarks': remarks,
        if (includeIsActive) 'isActive': isActive,
      };

  Supplier copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? pan,
    Money? openingBalance,
    bool? isActive,
    String? remarks,
    SupplierBalance? balance,
  }) =>
      Supplier(
        id: id,
        name: name ?? this.name,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        pan: pan ?? this.pan,
        openingBalance: openingBalance ?? this.openingBalance,
        isActive: isActive ?? this.isActive,
        remarks: remarks ?? this.remarks,
        balance: balance ?? this.balance,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// What the shop still owes one supplier, derived from the documents.
///
///     outstanding = opening balance + purchases − payments that are not cancelled
///
/// There is no `current_balance` column anywhere. A stored total can drift away
/// from the rows that produced it; this cannot.
///
/// A cheque handed over but not yet debited counts as paid — the shop has
/// parted with it — while still being reported separately as [uncleared],
/// because that money has not actually left the bank.
class SupplierBalance {
  const SupplierBalance({
    this.openingBalance = Money.zero,
    this.purchaseTotal = Money.zero,
    this.clearedTotal = Money.zero,
    this.uncleared = Money.zero,
    this.outstanding = Money.zero,
    this.billCount = 0,
    this.paymentCount = 0,
  });

  final Money openingBalance;
  final Money purchaseTotal;

  /// Payments that have actually left the bank.
  final Money clearedTotal;

  /// Issued but not yet debited — counted as paid, reported separately.
  final Money uncleared;

  /// Read from the server rather than recomputed here.
  ///
  /// The arithmetic is simple enough to repeat, and that is precisely the
  /// danger: two implementations of the same sum are two chances for the
  /// balance card and the ledger under it to disagree about one supplier.
  final Money outstanding;

  final int billCount;
  final int paymentCount;

  /// Cleared plus issued-but-uncleared. Cancelled payments settled nothing and
  /// are in neither.
  Money get paidTotal => clearedTotal + uncleared;

  bool get isSettled => outstanding.isZero;

  /// True when anything at all is filed against the supplier — which is what
  /// decides whether they can be deleted or only deactivated.
  bool get hasHistory => billCount > 0 || paymentCount > 0;

  /// Null when the payload carried no balance, so "not loaded" stays
  /// distinguishable from "settled".
  static SupplierBalance? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return SupplierBalance(
      openingBalance: WireCodec.money(json['openingBalance']),
      purchaseTotal: WireCodec.money(json['purchaseTotal']),
      clearedTotal: WireCodec.money(json['clearedTotal']),
      uncleared: WireCodec.money(json['unclearedTotal']),
      outstanding: WireCodec.money(json['outstanding']),
      billCount: WireCodec.integer(json['billCount']),
      paymentCount: WireCodec.integer(json['paymentCount']),
    );
  }
}

/// What a supplier's books did over one date window.
///
/// The six figures the statement header and the detail screen's range card both
/// show, so the two cannot disagree about a window they are both looking at.
/// Every one of them is derived by the server; none is stored.
class SupplierWindow {
  const SupplierWindow({
    this.openingAsOf = Money.zero,
    this.purchaseTotal = Money.zero,
    this.paymentTotal = Money.zero,
    this.unclearedTotal = Money.zero,
    this.closing = Money.zero,
    this.billCount = 0,
    this.paymentCount = 0,
  });

  /// Owed on the morning the window opens — the balance carried in.
  ///
  /// The figure that makes a window necessary at all: without it the movements
  /// inside it would appear to start from zero, and the closing balance would
  /// not reconcile with the card above it.
  final Money openingAsOf;

  final Money purchaseTotal;

  /// Payments that settled something. Cancelled ones are not in here.
  final Money paymentTotal;

  /// The part of [paymentTotal] that is cheques the bank has not debited yet.
  final Money unclearedTotal;

  /// The balance carried out. The whole point of the window.
  final Money closing;

  final int billCount;

  /// Counts cancelled payments too: they are listed on the statement.
  final int paymentCount;

  bool get isEmpty => billCount == 0 && paymentCount == 0;

  static SupplierWindow fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const SupplierWindow();
    return SupplierWindow(
      openingAsOf: WireCodec.money(json['openingAsOf']),
      purchaseTotal: WireCodec.money(json['purchaseTotal']),
      paymentTotal: WireCodec.money(json['paymentTotal']),
      unclearedTotal: WireCodec.money(json['unclearedTotal']),
      closing: WireCodec.money(json['closing']),
      billCount: WireCodec.integer(json['billCount']),
      paymentCount: WireCodec.integer(json['paymentCount']),
    );
  }
}
