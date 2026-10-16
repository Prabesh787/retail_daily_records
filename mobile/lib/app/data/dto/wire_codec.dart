import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';

/// Readers for the JSON the API sends.
///
/// The backend is precise about its types — money as fixed-precision strings,
/// document dates as `YYYY-MM-DD`, timestamps as ISO-8601 — and these readers
/// are still tolerant, because the alternative to a tolerant read is a crash in
/// a screen when one field arrives in a shape nobody expected.
class WireCodec {
  WireCodec._();

  static String string(Object? value, [String fallback = '']) =>
      value?.toString() ?? fallback;

  static String? stringOrNull(Object? value) {
    final s = value?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  static double number(Object? value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static int integer(Object? value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool boolean(Object? value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  /// A **timestamp** — an instant, such as `createdAt`. Normalised to epoch
  /// millis.
  static int millis(Object? value, {int? fallback}) {
    final absent = fallback ?? DateTime.now().millisecondsSinceEpoch;
    if (value == null) return absent;
    if (value is num) {
      final n = value.toInt();
      // A 10-digit value is seconds, 13 digits is millis.
      return n < 100000000000 ? n * 1000 : n;
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) return parsed.millisecondsSinceEpoch;
    return int.tryParse(value.toString()) ?? absent;
  }

  static List<Map<String, dynamic>> objects(Object? value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  /// The `name` off a relation the API included, e.g. `supplier: { id, name }`.
  ///
  /// Null when the relation was not included, which is how a list row that came
  /// back without its supplier shows nothing rather than an empty string that
  /// reads as a supplier with no name.
  static String? nestedName(Object? value) {
    if (value is! Map) return null;
    return stringOrNull(value['name']);
  }

  /// A **document date** — a calendar day, not an instant.
  ///
  /// Deliberately not [millis]. The API sends these as `YYYY-MM-DD`, and
  /// `DateTime.parse` reads a bare date as *local* midnight; on a device in
  /// Kathmandu that is 18:15 UTC the previous day, so a bill dated the 17th
  /// would file itself under the 16th and quietly leave the day book short.
  /// Parsing as UTC midnight is what keeps a date the same date everywhere.
  static int? dateMs(Object? value) {
    if (value == null) return null;
    if (value is num) return millis(value);

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    // A full timestamp is trimmed to its date part first: the calendar day is
    // the whole meaning here, and the time of day would only reintroduce the
    // timezone shift this method exists to avoid.
    final parsed = NepaliDate.parseIsoDate(
      text.length > 10 ? text.substring(0, 10) : text,
    );
    if (parsed != null) return parsed.millisecondsSinceEpoch;

    final fallback = DateTime.tryParse(text);
    if (fallback == null) return null;
    final utc = fallback.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch;
  }

  /// Money as the fixed-precision string the API sends. A number is tolerated
  /// but should never arrive — the backend serialises decimals as strings so
  /// nothing is lost on the way here.
  static Money money(Object? value) => Money.fromWire(value);

  static Quantity quantity(Object? value) => Quantity.fromWire(value);

  /// A document date on the way out: epoch millis to the `YYYY-MM-DD` the API
  /// validates against.
  static String isoDate(int ms) => NepaliDate.toIsoDate(NepaliDate.fromMs(ms));

  static String? isoDateOrNull(int? ms) => ms == null ? null : isoDate(ms);
}
