import 'package:billrecord/app/core/domain/day_group.dart';
import 'package:billrecord/app/core/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// Day grouping sits under both the purchases list and the sales list, and the
/// header it produces carries the day's total. That total is the figure a
/// shopkeeper actually scans for, so the rule it has to keep is that the header
/// is summed from the rows beneath it and can never be carried alongside them.
void main() {
  const int day = 86400000;
  final int today = DateTime.utc(2026, 9, 2).millisecondsSinceEpoch;

  ({int date, String amount}) row(int dateMs, String amount) => (
    date: dateMs,
    amount: amount,
  );

  List<DayGroup<({int date, String amount})>> group(
    List<({int date, String amount})> rows,
  ) => groupByDay(rows, (r) => r.date, (r) => Money.fromWire(r.amount));

  test('rows on the same day land in one bucket', () {
    final groups = group([
      row(today, '1000.00'),
      row(today, '2500.00'),
      row(today - day, '400.00'),
    ]);

    expect(groups.length, 2);
    expect(groups.first.count, 2);
    expect(groups.last.count, 1);
  });

  test('the total is the sum of the rows under it', () {
    final groups = group([
      row(today, '1000.00'),
      row(today, '2500.50'),
      row(today, '0.07'),
    ]);

    // Summed in paisa, so the fraction that a double would lose survives.
    expect(groups.single.total, Money.fromWire('3500.57'));
  });

  test('the order the query returned is preserved', () {
    // The DAOs return newest first. Re-sorting here would silently override
    // whatever ordering the query was written to produce.
    final groups = group([
      row(today, '1.00'),
      row(today - day, '1.00'),
      row(today - 5 * day, '1.00'),
    ]);

    expect(groups.map((g) => g.dateMs).toList(), [
      today,
      today - day,
      today - 5 * day,
    ]);
  });

  test('rows keep their order inside a day', () {
    final groups = group([
      row(today, '1.00'),
      row(today, '2.00'),
      row(today, '3.00'),
    ]);

    expect(
      groups.single.rows.map((r) => r.amount).toList(),
      ['1.00', '2.00', '3.00'],
    );
  });

  test('a day that reappears later rejoins its own bucket', () {
    // Defensive: a list that is not perfectly date-sorted must not produce two
    // buckets for one day, each with half the day's total.
    final groups = group([
      row(today, '1000.00'),
      row(today - day, '500.00'),
      row(today, '250.00'),
    ]);

    expect(groups.length, 2);
    expect(groups.first.total, Money.fromWire('1250.00'));
  });

  test('an empty list groups into nothing', () {
    expect(group([]), isEmpty);
  });
}
