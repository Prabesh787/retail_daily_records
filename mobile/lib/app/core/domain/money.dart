/// Money and quantities, held as integers.
///
/// The backend stores money as `numeric(14,2)` and quantities as
/// `numeric(14,3)`, and puts them on the wire as fixed-precision **strings**
/// precisely so nothing is lost to a floating point type. SQLite has no decimal
/// type at all and its `REAL` cannot represent `0.01`, so this app stores the
/// scaled integer instead: money in **paisa**, quantities in **milli-units**.
///
/// That matters more here than in most apps. A supplier's outstanding is
/// derived by summing every bill and payment rather than being stored — on both
/// sides — so if the phone aggregates doubles and the server aggregates
/// decimals, the two answers drift apart. "The balance and the transactions
/// cannot disagree" is the whole premise of the product.
///
/// Rounding is half-away-from-zero throughout, matching `Decimal.ROUND_HALF_UP`
/// in `backend/src/common/utils/money.js`.
library;

import 'package:intl/intl.dart';

const int _moneyScale = 100; // 2 dp
const int _quantityScale = 1000; // 3 dp

/// Rounds `value / divisor` half away from zero, in integers only.
int _divRoundHalfUp(int value, int divisor) {
  final negative = (value < 0) != (divisor < 0);
  final absValue = value.abs();
  final absDivisor = divisor.abs();
  final quotient = absValue ~/ absDivisor;
  final remainder = absValue % absDivisor;
  // `>=` rather than `>` is what makes this HALF_UP rather than HALF_EVEN.
  final rounded = (remainder * 2 >= absDivisor) ? quotient + 1 : quotient;
  return negative ? -rounded : rounded;
}

/// Parses a fixed-precision decimal string into its scaled integer.
///
/// Deliberately not `double.parse` — `"0.07"` is not exactly representable, and
/// the point of this file is that it never becomes so.
int? _parseScaled(String? value, int scale) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;

  final match = RegExp(r'^([+-])?(\d+)(?:\.(\d*))?$').firstMatch(text);
  if (match == null) return null;

  final negative = match.group(1) == '-';
  final whole = match.group(2)!;
  final fraction = match.group(3) ?? '';

  final digits = scale.toString().length - 1; // 100 -> 2, 1000 -> 3
  var scaled = int.parse(whole) * scale;

  if (fraction.length <= digits) {
    final padded = fraction.padRight(digits, '0');
    if (padded.isNotEmpty) scaled += int.parse(padded);
  } else {
    scaled += int.parse(fraction.substring(0, digits));
    // One extra digit is all it takes to decide half-up.
    if (int.parse(fraction[digits]) >= 5) scaled += 1;
  }

  return negative ? -scaled : scaled;
}

/// The inverse: `10000000` at scale 100 becomes `"100000.00"`.
String _formatScaled(int scaled, int scale) {
  final digits = scale.toString().length - 1;
  final negative = scaled < 0;
  final absolute = scaled.abs();
  final whole = absolute ~/ scale;
  final fraction = (absolute % scale).toString().padLeft(digits, '0');
  return '${negative ? '-' : ''}$whole.$fraction';
}

/// Nepali/Indian digit grouping — `12,34,567.00`, not `1,234,567.00`.
final NumberFormat _grouped = NumberFormat('#,##,##0.00');
final NumberFormat _groupedWhole = NumberFormat('#,##,##0');

/// An amount of money, in paisa.
class Money implements Comparable<Money> {
  const Money.fromPaisa(this.paisa);

  /// From the fixed-precision string the API sends, e.g. `"100000.00"`.
  ///
  /// Null or unparseable becomes [zero]: a missing amount is not a crash, and
  /// the server never omits a required one.
  factory Money.fromWire(Object? value) {
    if (value is num) return Money.fromRupees(value);
    return Money.fromPaisa(_parseScaled(value as String?, _moneyScale) ?? 0);
  }

  /// From whatever SQLite handed back for an INTEGER column.
  factory Money.fromColumn(Object? value) {
    if (value == null) return zero;
    if (value is int) return Money.fromPaisa(value);
    return Money.fromPaisa(int.tryParse(value.toString()) ?? 0);
  }

  /// From major units. For seeds and tests — never for reading a value that
  /// already exists in exact form.
  ///
  /// `num.round()` is already half-away-from-zero, matching the rest of the file.
  factory Money.fromRupees(num rupees) =>
      Money.fromPaisa((rupees * _moneyScale).round());

  /// Text someone typed into an amount field. Commas are tolerated because a
  /// keyboard makes them easy to type and they carry no meaning.
  static Money? tryParse(String? input) {
    final scaled = _parseScaled(input?.replaceAll(',', ''), _moneyScale);
    return scaled == null ? null : Money.fromPaisa(scaled);
  }

  static const Money zero = Money.fromPaisa(0);

  final int paisa;

  bool get isZero => paisa == 0;
  bool get isNegative => paisa < 0;
  bool get isPositive => paisa > 0;

  Money operator +(Money other) => Money.fromPaisa(paisa + other.paisa);
  Money operator -(Money other) => Money.fromPaisa(paisa - other.paisa);
  Money operator -() => Money.fromPaisa(-paisa);

  Money get abs => Money.fromPaisa(paisa.abs());

  bool operator >(Money other) => paisa > other.paisa;
  bool operator <(Money other) => paisa < other.paisa;
  bool operator >=(Money other) => paisa >= other.paisa;
  bool operator <=(Money other) => paisa <= other.paisa;

  static Money sum(Iterable<Money> values) =>
      values.fold(zero, (total, value) => total + value);

  /// The value as the API expects it: `"100000.00"`.
  String toWire() => _formatScaled(paisa, _moneyScale);

  /// The column value. Named rather than exposing [paisa] at call sites, so a
  /// DAO reads the same on both sides of the boundary.
  int toColumn() => paisa;

  /// Display only. Never feed this back into arithmetic.
  double get asDouble => paisa / _moneyScale;

  /// `Rs 1,00,000.00`, or without decimals for tiles that do not need them.
  String display({String symbol = 'Rs', bool decimals = true}) {
    final body =
        decimals ? _grouped.format(asDouble) : _groupedWhole.format(asDouble);
    return symbol.isEmpty ? body : '$symbol $body';
  }

  /// Short form for narrow columns: `Rs 1.20L`, `Rs 45.5K`, `Rs 2.30Cr`.
  String displayShort({String symbol = 'Rs'}) {
    final value = asDouble;
    final magnitude = value.abs();
    final sign = value < 0 ? '-' : '';

    final String body;
    if (magnitude >= 10000000) {
      body = '${(magnitude / 10000000).toStringAsFixed(2)}Cr';
    } else if (magnitude >= 100000) {
      body = '${(magnitude / 100000).toStringAsFixed(2)}L';
    } else if (magnitude >= 1000) {
      body = '${(magnitude / 1000).toStringAsFixed(1)}K';
    } else {
      body = _groupedWhole.format(magnitude);
    }

    return '${symbol.isEmpty ? '' : '$symbol '}$sign$body';
  }

  @override
  int compareTo(Money other) => paisa.compareTo(other.paisa);

  @override
  bool operator ==(Object other) => other is Money && other.paisa == paisa;

  @override
  int get hashCode => paisa.hashCode;

  @override
  String toString() => 'Money(${toWire()})';
}

/// A quantity on an invoice line, in thousandths of a unit.
class Quantity implements Comparable<Quantity> {
  const Quantity.fromMilli(this.milli);

  factory Quantity.fromWire(Object? value) {
    if (value is num) return Quantity.fromUnits(value);
    return Quantity.fromMilli(
      _parseScaled(value as String?, _quantityScale) ?? 0,
    );
  }

  factory Quantity.fromColumn(Object? value) {
    if (value == null) return zero;
    if (value is int) return Quantity.fromMilli(value);
    return Quantity.fromMilli(int.tryParse(value.toString()) ?? 0);
  }

  factory Quantity.fromUnits(num units) =>
      Quantity.fromMilli((units * _quantityScale).round());

  static Quantity? tryParse(String? input) {
    final scaled = _parseScaled(input?.replaceAll(',', ''), _quantityScale);
    return scaled == null ? null : Quantity.fromMilli(scaled);
  }

  static const Quantity zero = Quantity.fromMilli(0);

  final int milli;

  bool get isZero => milli == 0;
  bool get isPositive => milli > 0;

  Quantity operator +(Quantity other) => Quantity.fromMilli(milli + other.milli);
  Quantity operator -(Quantity other) => Quantity.fromMilli(milli - other.milli);

  static Quantity sum(Iterable<Quantity> values) =>
      values.fold(zero, (total, value) => total + value);

  String toWire() => _formatScaled(milli, _quantityScale);

  int toColumn() => milli;

  double get asDouble => milli / _quantityScale;

  /// Trailing zeros dropped, so a line reads `5 METER` rather than `5.000`.
  String display() {
    if (milli % _quantityScale == 0) return (milli ~/ _quantityScale).toString();
    return toWire().replaceFirst(RegExp(r'0+$'), '');
  }

  @override
  int compareTo(Quantity other) => milli.compareTo(other.milli);

  @override
  bool operator ==(Object other) => other is Quantity && other.milli == milli;

  @override
  int get hashCode => milli.hashCode;

  @override
  String toString() => 'Quantity(${toWire()})';
}

/// The amount of one itemised-sale invoice line.
///
/// The single place a line amount is ever produced, mirroring
/// `calculateLineAmount` in the backend — which likewise ignores whatever
/// `amount` a client sends and recomputes it. Both sides must agree digit for
/// digit, or a sale's total will not match its own lines after a sync.
///
/// Quantity carries 3 dp and price 2 dp, so their product is exact at 5 dp; it
/// is rounded to paisa **once**, after the discount comes off, exactly as
/// `toMoney(toQuantity(q).times(price).minus(discount))` does.
Money calculateLineAmount(
  Quantity quantity,
  Money unitPrice, {
  Money discount = Money.zero,
}) {
  const int toFiveDp = _quantityScale; // paisa (1e-2) -> 1e-5
  final scaled = quantity.milli * unitPrice.paisa - discount.paisa * toFiveDp;
  return Money.fromPaisa(_divRoundHalfUp(scaled, toFiveDp));
}
