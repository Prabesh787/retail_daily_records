import 'package:intl/intl.dart';

import 'nepali_date.dart';

/// Dates, and the one distinction that has to hold everywhere.
///
/// This app deals with two kinds of moment and they are not interchangeable:
///
///   * a **document date** — the calendar day written on a bill. It has no time
///     of day, and it is the same day in every timezone. Held as the epoch
///     millis of **UTC midnight**, which is exactly what the API's plain
///     `YYYY-MM-DD` parses to, so a date survives the round trip unchanged.
///   * a **timestamp** — when a record was created. A real instant, shown in
///     the device's local time, because "9:40 am" means the shop's morning.
///
/// Mixing them is the bug this file is arranged to prevent. Kathmandu is
/// UTC+05:45, so a local midnight read as UTC lands on the *previous* day: a
/// bill dated the 17th files itself under the 16th, and the day book comes up
/// short with nothing to say why. Day values go through [dayOf] and [dayMs];
/// instants go through [fromMs].
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _day = DateFormat('dd MMM yyyy');
  static final DateFormat _dayShort = DateFormat('dd MMM');
  static final DateFormat _dayTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _month = DateFormat('MMMM yyyy');
  static final DateFormat _weekday = DateFormat('EEE');
  static final DateFormat _time = DateFormat('h:mm a');

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// An **instant**, in local time. For timestamps only.
  static DateTime fromMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  /// A **document date**, read back as the calendar day it stands for.
  static DateTime dayOf(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  /// The calendar day of [date] as a document date.
  ///
  /// Takes the year, month and day as they read on the given [DateTime] and
  /// drops the time — a date the user picked at local midnight is the day they
  /// tapped, whatever that instant is in UTC.
  static int dayMs(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch;

  // ---- Formatting ---------------------------------------------------------

  static String formatDate(int ms) => _day.format(dayOf(ms));
  static String formatDateShort(int ms) => _dayShort.format(dayOf(ms));
  static String formatMonth(int ms) => _month.format(dayOf(ms));
  static String formatWeekday(int ms) => _weekday.format(dayOf(ms));

  /// Timestamps, in the device's own time.
  static String formatDateTime(int ms) => _dayTime.format(fromMs(ms));

  /// `9:40 am`. Several sales share one date, so a row inside a day group
  /// carries the time rather than repeating the day.
  static String formatTime(int ms) => _time.format(fromMs(ms)).toLowerCase();

  /// Both calendars, the way the paperwork carries them: `10 Bhadra 2083 · 26
  /// Aug 2026`. The shop reads BS, the bank and the invoice read AD, and a
  /// record shown in only one of them has to be converted in someone's head.
  ///
  /// [bs] is the stored string where there is one — what was actually written
  /// on the bill — and is derived from [ms] only as a fallback.
  static String datePair(int ms, [String? bs]) {
    final bsText = NepaliDate.format(bs ?? NepaliDate.msToBs(ms));
    final adText = formatDate(ms);
    return bsText.isEmpty ? adText : '$bsText · $adText';
  }

  // ---- Days ---------------------------------------------------------------

  /// Today, as the shop's calendar day. The device's local date, held as a
  /// document date.
  static int todayMs() => NepaliDate.todayMs();

  /// [days] before today.
  static int daysAgoMs(int days) =>
      todayMs() - Duration(days: days).inMilliseconds;

  static int startOfMonthMs([DateTime? on]) {
    final d = on ?? DateTime.now();
    return DateTime.utc(d.year, d.month).millisecondsSinceEpoch;
  }

  static int endOfMonthMs([DateTime? on]) {
    final d = on ?? DateTime.now();
    // Day 0 of next month is the last day of this one.
    return DateTime.utc(d.year, d.month + 1, 0).millisecondsSinceEpoch;
  }

  /// Whole days from today to [ms]. Negative is in the past.
  ///
  /// Counted between calendar days rather than by elapsed hours: a cheque dated
  /// tomorrow is due "in 1 day" from any time today, not in 0 days because it
  /// is currently evening.
  ///
  /// Floored rather than truncated, so a value that is not day-aligned still
  /// reads as the day it falls in. `~/` rounds toward zero, which would put
  /// something half a day in the past at "today".
  static int daysUntil(int ms) =>
      ((ms - todayMs()) / Duration(days: 1).inMilliseconds).floor();

  /// "Today", "Yesterday", "in 3 days", "4 days ago", then an absolute date.
  static String relativeDay(int ms) {
    final days = daysUntil(ms);
    return switch (days) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      > 1 && < 14 => 'in $days days',
      < -1 && > -7 => '${-days} days ago',
      _ => formatDate(ms),
    };
  }

  /// "2 hours ago" style label, for timestamps.
  static String relative(int? ms) {
    if (ms == null) return 'never';
    final diff = DateTime.now().difference(fromMs(ms));
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return formatDate(ms);
  }
}
