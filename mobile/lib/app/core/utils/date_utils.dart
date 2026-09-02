import 'package:intl/intl.dart';

/// All dates are stored as epoch-millis integers (UTC) so they sort in SQL and
/// survive the JSON round trip to any backend without timezone ambiguity.
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _day = DateFormat('dd MMM yyyy');
  static final DateFormat _dayShort = DateFormat('dd MMM');
  static final DateFormat _dayTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _month = DateFormat('MMMM yyyy');
  static final DateFormat _weekday = DateFormat('EEE');

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
}
