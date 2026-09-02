import '../utils/date_utils.dart';

extension DateTimeX on DateTime {
  int get ms => millisecondsSinceEpoch;
  DateTime get startOfDay => AppDateUtils.startOfDay(this);
  DateTime get endOfDay => AppDateUtils.endOfDay(this);
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

extension EpochX on int {
  DateTime get asDate => AppDateUtils.fromMs(this);
  String get dateLabel => AppDateUtils.formatDate(this);
  String get dateTimeLabel => AppDateUtils.formatDateTime(this);
  String get relativeLabel => AppDateUtils.relative(this);
}
