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

  /// A cheque date as the app actually holds one: a calendar day, built from a
  /// moment part-way through it. The hour is what the old local-midnight
  /// convention got wrong — east of UTC it landed the date on the day before.
  int dueOn(DateTime day, {int hour = 12}) => AppDateUtils.dayMs(
        DateTime(day.year, day.month, day.day, hour),
      );

  final today = DateTime.now();

  test('a cheque dated today is due this week, not overdue', () {
    expect(bucketFor(dueOn(today, hour: 9)), 'week');
  });

  test('the time of day does not move a cheque between buckets', () {
    // A date has no time of day, and this is what says so: the same calendar
    // day keyed at midnight and at eleven at night is one date, not two.
    expect(dueOn(today, hour: 0), dueOn(today, hour: 23));
    expect(bucketFor(dueOn(today, hour: 0)), 'week');
    expect(bucketFor(dueOn(today, hour: 23)), 'week');
  });

  test('yesterday is overdue', () {
    expect(bucketFor(dueOn(today.subtract(const Duration(days: 1)))), 'overdue');
  });

  test('the seventh day is still this week', () {
    expect(bucketFor(dueOn(today.add(const Duration(days: 7)))), 'week');
  });

  test('the eighth day is later', () {
    expect(bucketFor(dueOn(today.add(const Duration(days: 8)))), 'later');
  });

  test('a long-overdue cheque stays overdue', () {
    expect(
      bucketFor(dueOn(today.subtract(const Duration(days: 120)))),
      'overdue',
    );
  });

  test('daysUntil counts whole days, ignoring the clock', () {
    final tomorrow = today.add(const Duration(days: 1));

    expect(AppDateUtils.daysUntil(dueOn(tomorrow, hour: 1)), 1);
    expect(AppDateUtils.daysUntil(dueOn(tomorrow, hour: 23)), 1);
    expect(AppDateUtils.daysUntil(dueOn(today, hour: 23)), 0);
  });

  /// The bug the whole day/instant split exists to prevent. Kathmandu is
  /// UTC+05:45, so local midnight read as UTC is the previous day — a bill
  /// dated the 17th would file itself under the 16th and leave the day book
  /// short with nothing to say why.
  test('a date is the day it was written, in any timezone', () {
    final ms = AppDateUtils.dayMs(DateTime(2026, 8, 26, 0, 30));

    expect(ms, DateTime.utc(2026, 8, 26).millisecondsSinceEpoch);
    expect(AppDateUtils.dayOf(ms).day, 26);
    expect(AppDateUtils.formatDate(ms), '26 Aug 2026');
  });
}
