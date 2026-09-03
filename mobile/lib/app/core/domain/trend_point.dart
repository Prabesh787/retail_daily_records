import 'money.dart';

/// One day's takings.
///
/// A domain type rather than a widget one, because the repository that produces
/// a fortnight of these must not have to import the chart that draws them — the
/// data layer depending on the widget layer is the wrong way round, and it is
/// the sort of import that quietly becomes load-bearing.
class TrendPoint {
  const TrendPoint({required this.dateMs, required this.amount});

  final int dateMs;
  final Money amount;
}
