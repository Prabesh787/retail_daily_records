import 'money.dart';

/// A day's worth of records, with the day's total.
///
/// Both the purchases list and the sales list are read day by day — the total
/// on the header is the figure being scanned for and the rows beneath it are
/// the working — so the grouping lives here rather than in either screen.
class DayGroup<T> {
  DayGroup({required this.dateMs, required this.rows, required this.total});

  final int dateMs;
  final List<T> rows;

  /// Summed from [rows], never carried alongside them, so the header and the
  /// list under it cannot disagree.
  final Money total;

  int get count => rows.length;
}

/// Buckets an already date-sorted list by day.
///
/// Insertion order is preserved, so a list the DAO returned newest-first stays
/// newest-first — re-sorting here would quietly override whatever ordering the
/// query was written to produce.
List<DayGroup<T>> groupByDay<T>(
  Iterable<T> rows,
  int Function(T row) dateOf,
  Money Function(T row) amountOf,
) {
  final buckets = <int, List<T>>{};

  for (final row in rows) {
    buckets.putIfAbsent(dateOf(row), () => <T>[]).add(row);
  }

  return [
    for (final entry in buckets.entries)
      DayGroup<T>(
        dateMs: entry.key,
        rows: entry.value,
        total: Money.sum(entry.value.map(amountOf)),
      ),
  ];
}
