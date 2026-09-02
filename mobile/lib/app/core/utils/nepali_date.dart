/// Bikram Sambat <-> Gregorian conversion.
///
/// A direct port of `backend/src/common/utils/nepali-date.js`. The two
/// implementations **must** agree: the shop reads BS, the database sorts on AD,
/// and a report rendered offline on the phone has to match the same report
/// rendered by the server. `test/nepali_date_test.dart` checks that against a
/// golden fixture generated from the JS, so a drift is a failing test rather
/// than a date that is quietly one day out.
///
/// BS months have no formula — their length is fixed by an almanac each year —
/// so the only correct implementation is a lookup table. [bsMonthDays] covers
/// BS 2000-2100 (AD 1943-2044), anchored on the one date every published table
/// agrees on:
///
///   1 Baishakh 2000 BS = 14 April 1943 AD
///
/// Conversion walks whole months from that anchor, so a wrong row shows up as a
/// drifting date rather than as a silent off-by-one.
///
/// Known defect, inherited deliberately: BS 2096 sums to 364 days, which is not
/// a real year length. It is a copy-propagated error present in the backend's
/// table and in most published BS libraries, so every date from BS 2096 (AD
/// 2039) onward is one day early. It is kept **because the backend has it** —
/// agreeing with the server matters more than being right about 2039 — and
/// [malformedYears] documents it rather than hiding it. Fix both sides together
/// or neither.
library;

class NepaliDate {
  NepaliDate._();

  /// 1 Baishakh 2000 BS.
  static const int anchorBsYear = 2000;
  static final int _anchorAdUtcMs =
      DateTime.utc(1943, 4, 14).millisecondsSinceEpoch;

  static const int _dayMs = 86400000;

  static const int minBsYear = 2000;
  static const int maxBsYear = 2100;

  /// Month names as the shop says them, index 0 = Baishakh.
  static const List<String> monthNames = [
    'Baishakh',
    'Jestha',
    'Ashadh',
    'Shrawan',
    'Bhadra',
    'Ashwin',
    'Kartik',
    'Mangsir',
    'Poush',
    'Magh',
    'Falgun',
    'Chaitra',
  ];

  static final Map<int, int> _yearLengthCache = {};

  /// Total days in a BS year. Memoised — the trend report asks repeatedly.
  static int bsYearLength(int year) => _yearLengthCache.putIfAbsent(
        year,
        () => bsMonthDays[year]!.fold(0, (total, days) => total + days),
      );

  /// Days in one BS month, or null if the year or month is out of range.
  static int? daysInBsMonth(int year, int month) {
    if (month < 1 || month > 12) return null;
    return bsMonthDays[year]?[month - 1];
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  // ---- AD side -------------------------------------------------------------

  /// `YYYY-MM-DD` to UTC midnight, or null if it is not a real date.
  ///
  /// The round-trip check is what rejects an impossible date such as
  /// `2026-02-31`, which `DateTime.utc` would otherwise roll into March.
  static DateTime? parseIsoDate(String? value) {
    final match =
        RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch((value ?? '').trim());
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    final date = DateTime.utc(year, month, day);
    if (date.month != month || date.day != day) return null;
    return date;
  }

  /// A UTC-midnight [DateTime] as the plain `YYYY-MM-DD` used on the wire.
  static String toIsoDate(DateTime date) {
    final utc = date.isUtc ? date : date.toUtc();
    return '${utc.year}-${_pad(utc.month)}-${_pad(utc.day)}';
  }

  /// Epoch millis (how every date column here is stored) to UTC midnight.
  static DateTime fromMs(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  /// UTC midnight of the given date, as the epoch millis the DAOs store.
  ///
  /// Dates are stored at UTC midnight rather than local midnight so the same
  /// document sorts into the same day whatever the device's timezone is.
  static int toMs(DateTime date) {
    final utc = date.isUtc ? date : date.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch;
  }

  /// Today, as the shop's calendar day.
  ///
  /// Taken from the device's local date rather than UTC: Kathmandu is UTC+05:45,
  /// so a UTC-derived day would still be reporting yesterday's takings until a
  /// quarter past six every morning.
  static int todayMs() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  // ---- Conversion ----------------------------------------------------------

  /// Gregorian to Bikram Sambat, as `YYYY-MM-DD`. Null when out of range.
  static String? adToBs(DateTime? date) {
    if (date == null) return null;
    final utc = date.isUtc ? date : date.toUtc();
    final ms = DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch;

    var remaining = ((ms - _anchorAdUtcMs) / _dayMs).round();
    if (remaining < 0) return null;

    var year = anchorBsYear;
    for (;;) {
      if (year > maxBsYear) return null;
      final length = bsYearLength(year);
      if (remaining < length) break;
      remaining -= length;
      year += 1;
    }

    final months = bsMonthDays[year]!;
    var month = 1;
    while (remaining >= months[month - 1]) {
      remaining -= months[month - 1];
      month += 1;
    }

    return '$year-${_pad(month)}-${_pad(remaining + 1)}';
  }

  /// Same, from an AD `YYYY-MM-DD` string.
  static String? adIsoToBs(String? isoDate) => adToBs(parseIsoDate(isoDate));

  /// Same, from the epoch millis a date column holds.
  static String? msToBs(int? ms) => ms == null ? null : adToBs(fromMs(ms));

  /// Bikram Sambat to Gregorian. The inverse of [adToBs], kept beside it so the
  /// two can never end up anchored on different tables.
  static DateTime? bsToAd(String? value) {
    final match =
        RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch((value ?? '').trim());
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    if (year < minBsYear || year > maxBsYear) return null;
    if (month < 1 || month > 12) return null;

    final months = bsMonthDays[year]!;
    if (day < 1 || day > months[month - 1]) return null;

    var days = 0;
    for (var y = anchorBsYear; y < year; y += 1) {
      days += bsYearLength(y);
    }
    for (var m = 1; m < month; m += 1) {
      days += months[m - 1];
    }
    days += day - 1;

    return DateTime.fromMillisecondsSinceEpoch(
      _anchorAdUtcMs + days * _dayMs,
      isUtc: true,
    );
  }

  /// BS `YYYY-MM-DD` to the AD `YYYY-MM-DD` string.
  static String? bsToAdIso(String? value) {
    final date = bsToAd(value);
    return date == null ? null : toIsoDate(date);
  }

  /// BS `YYYY-MM-DD` to the epoch millis a date column holds.
  static int? bsToMs(String? value) => bsToAd(value)?.millisecondsSinceEpoch;

  // ---- Display -------------------------------------------------------------

  /// `2083-05-10` becomes `10 Bhadra 2083`.
  ///
  /// Returns the input unchanged if it is not a BS date this table can read — a
  /// stored string is what the paperwork said, and is never worth losing to a
  /// formatting failure.
  static String format(String? bsDate, {bool short = false}) {
    final match =
        RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch((bsDate ?? '').trim());
    if (match == null) return bsDate ?? '';

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12) return bsDate!;

    final name = monthNames[month - 1];
    return short ? '$day ${name.substring(0, 3)}' : '$day $name $year';
  }

  /// "Today", "Yesterday", or the BS date — the label a day group carries.
  static String relativeDay(int dateMs) {
    final today = todayMs();
    final diff = ((today - dateMs) / _dayMs).round();
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return format(msToBs(dateMs));
  }

  // ---- Self-check ----------------------------------------------------------

  /// BS years in the table that are not 365 or 366 days long.
  ///
  /// A test asserts this is exactly `{2096}` — the one known-bad row described
  /// in the library doc — so a *new* bad row fails loudly instead of joining it,
  /// and so fixing one side without the other is caught.
  static List<int> malformedYears() {
    final bad = <int>[];
    for (final year in bsMonthDays.keys) {
      final length = bsYearLength(year);
      if (length != 365 && length != 366) bad.add(year);
    }
    bad.sort();
    return bad;
  }

  /// Days in each of the 12 BS months, keyed by BS year.
  ///
  /// Generated from `backend/src/common/utils/nepali-date.js`. Do not hand-edit:
  /// regenerate both sides together or the golden test will fail.
  static const Map<int, List<int>> bsMonthDays = {
    2000: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2001: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2002: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2003: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2004: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2005: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2006: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2007: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2008: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    2009: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2010: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2011: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2012: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2013: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2014: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2015: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2016: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2017: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2018: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2019: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2020: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2021: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2022: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2023: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2024: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2025: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2026: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2027: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2028: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2029: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    2030: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2031: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2032: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2033: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2034: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2035: [30, 32, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    2036: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2037: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2038: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2039: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2040: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2041: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2042: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2043: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2044: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2045: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2046: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2047: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2048: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2049: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2050: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2051: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2052: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2053: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2054: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2055: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2056: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    2057: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2058: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2059: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2060: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2061: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2062: [31, 31, 31, 32, 31, 31, 29, 30, 29, 30, 29, 31],
    2063: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2064: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2065: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2066: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    2067: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2068: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2069: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2070: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2071: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2072: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2073: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2074: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2075: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2076: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2077: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2078: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2079: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2080: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2081: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2082: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2084: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
    2085: [31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30],
    2086: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    2087: [31, 31, 32, 31, 31, 31, 30, 29, 30, 30, 30, 30],
    2088: [30, 31, 32, 32, 30, 31, 30, 30, 29, 30, 30, 30],
    2089: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    2090: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    2091: [31, 31, 32, 31, 31, 31, 30, 30, 29, 30, 30, 30],
    2092: [30, 31, 32, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    2093: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    2094: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
    2095: [31, 31, 32, 31, 31, 31, 30, 29, 30, 30, 30, 30],
    2096: [30, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2097: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    2098: [31, 31, 32, 31, 31, 31, 29, 30, 29, 30, 29, 31],
    2099: [31, 31, 32, 31, 31, 31, 30, 29, 29, 30, 30, 30],
    2100: [31, 32, 31, 32, 30, 31, 30, 29, 30, 29, 30, 30],
  };
}
