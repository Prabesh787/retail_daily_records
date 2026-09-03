import '../../core/domain/money.dart';
import '../../core/utils/nepali_date.dart';

/// Tolerant readers for JSON coming off the wire.
///
/// The API's own types are narrow — dates are `YYYY-MM-DD`, money is a
/// fixed-precision string, timestamps are epoch millis — but a row can also
/// come from an older build, a hand-fixed record or a future change to the
/// server. So dates are read whether they arrive as millis, seconds or an ISO
/// string, booleans as `true`, `1` or `"1"`, money as a number or a string.
/// Parsing defensively here means a change on the wire never turns into a
/// crash in a DAO.
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

  /// Normalises whatever the server calls a timestamp into epoch millis.
  static int millis(Object? value, {int? fallback}) {
    final now = fallback ?? DateTime.now().millisecondsSinceEpoch;
    if (value == null) return now;
    if (value is num) {
      final n = value.toInt();
      // A 10-digit value is seconds, 13 digits is millis.
      return n < 100000000000 ? n * 1000 : n;
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) return parsed.millisecondsSinceEpoch;
    return int.tryParse(value.toString()) ?? now;
  }

  static List<Map<String, dynamic>> objects(Object? value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
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
}
