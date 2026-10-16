import '../utils/date_utils.dart';

extension DateTimeX on DateTime {
  int get ms => millisecondsSinceEpoch;

  /// This calendar day as a document date. See [AppDateUtils].
  int get dayMs => AppDateUtils.dayMs(this);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

extension EpochX on int {
  /// Read as a calendar day, which is what every date on a record is.
  DateTime get asDate => AppDateUtils.dayOf(this);
  String get dateLabel => AppDateUtils.formatDate(this);
  String get dateTimeLabel => AppDateUtils.formatDateTime(this);
  String get relativeLabel => AppDateUtils.relative(this);
}
