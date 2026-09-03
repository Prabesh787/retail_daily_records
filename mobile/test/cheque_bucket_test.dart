import 'package:billrecord/app/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cheque register splits rows into overdue / next 7 days / later, and that
/// split rests entirely on `daysUntil`. It is the kind of arithmetic that looks
/// obviously right and is off by one at the boundaries — where "due today" and
/// "due in exactly seven days" land decides whether a shopkeeper is told to
/// find money this week or next.
///
/// The bucketing rule under test, as the controller applies it:
///   days <  0  overdue
///   days <= 7  this week
///   else       later
void main() {
  String bucketFor(int ms) {
    final days = AppDateUtils.daysUntil(ms);
    if (days < 0) return 'overdue';
    if (days <= 7) return 'week';
    return 'later';
  }

  int atHour(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour).millisecondsSinceEpoch;

  final today = DateTime.now();

  test('a cheque dated today is due this week, not overdue', () {
    expect(bucketFor(atHour(today, 9)), 'week');
  });

  test('the time of day does not move a cheque between buckets', () {
    // daysUntil has to compare whole days. Comparing raw timestamps would put
    // a cheque dated this morning into "overdue" by mid-afternoon.
    expect(bucketFor(atHour(today, 0)), 'week');
    expect(bucketFor(atHour(today, 23)), 'week');
  });

  test('yesterday is overdue', () {
    expect(bucketFor(atHour(today.subtract(const Duration(days: 1)), 12)),
        'overdue');
  });

  test('the seventh day is still this week', () {
    expect(
      bucketFor(atHour(today.add(const Duration(days: 7)), 12)),
      'week',
    );
  });

  test('the eighth day is later', () {
    expect(
      bucketFor(atHour(today.add(const Duration(days: 8)), 12)),
      'later',
    );
  });

  test('a long-overdue cheque stays overdue', () {
    expect(
      bucketFor(atHour(today.subtract(const Duration(days: 120)), 12)),
      'overdue',
    );
  });

  test('daysUntil counts whole days, ignoring the clock', () {
    final tomorrow = today.add(const Duration(days: 1));

    // Same day, twelve hours apart, must be the same number of days out.
    expect(AppDateUtils.daysUntil(atHour(tomorrow, 1)), 1);
    expect(AppDateUtils.daysUntil(atHour(tomorrow, 23)), 1);
    expect(AppDateUtils.daysUntil(atHour(today, 23)), 0);
  });
}
