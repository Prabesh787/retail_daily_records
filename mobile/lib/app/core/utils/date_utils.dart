import 'package:intl/intl.dart';

import 'nepali_date.dart';

/// All dates are stored as epoch-millis integers (UTC) so they sort in SQL and
/// survive the JSON round trip to any backend without timezone ambiguity.
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _day = DateFormat('dd MMM yyyy');
  static final DateFormat _dayShort = DateFormat('dd MMM');
  static final DateFormat _dayTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _month = DateFormat('MMMM yyyy');
  static final DateFormat _weekday = DateFormat('EEE');
  static final DateFormat _time = DateFormat('h:mm a');

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static DateTime fromMs(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms);

  static String formatDate(int ms) => _day.format(fromMs(ms));
  static String formatDateShort(int ms) => _dayShort.format(fromMs(ms));
  static String formatDateTime(int ms) => _dayTime.format(fromMs(ms));
  static String formatMonth(int ms) => _month.format(fromMs(ms));
  static String formatWeekday(int ms) => _weekday.format(fromMs(ms));

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static int startOfTodayMs() =>
      startOfDay(DateTime.now()).millisecondsSinceEpoch;
  static int endOfTodayMs() => endOfDay(DateTime.now()).millisecondsSinceEpoch;

  static int startOfMonthMs([DateTime? on]) {
    final d = on ?? DateTime.now();
    return DateTime(d.year, d.month).millisecondsSinceEpoch;
  }

  static int endOfMonthMs([DateTime? on]) {
    final d = on ?? DateTime.now();
    // Day 0 of next month == last day of this month.
    return DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999)
        .millisecondsSinceEpoch;
  }

  static int daysAgoMs(int days) => startOfDay(
        DateTime.now().subtract(Duration(days: days)),
      ).millisecondsSinceEpoch;

  /// "2 hours ago" style label for the sync chip and activity feed.
  static String relative(int? ms) {
    if (ms == null) return 'never';
    final diff = DateTime.now().difference(fromMs(ms));
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return formatDate(ms);
  }

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

  /// Whole days from today to [ms]. Negative is in the past.
  ///
  /// Counted between calendar days rather than by elapsed hours: a cheque dated
  /// tomorrow is due "in 1 day" from any time today, not in 0 days because it
  /// is currently evening.
  static int daysUntil(int ms) {
    final from = startOfDay(DateTime.now());
    final to = startOfDay(fromMs(ms));
    return to.difference(from).inDays;
  }

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
}
