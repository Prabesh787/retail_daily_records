import '../../core/utils/nepali_date.dart';
import '../dto/wire_codec.dart';

/// A Nepali fiscal year, e.g. `2082/83`.
///
/// Every purchase, payment and sale belongs to one, so nothing can be recorded
/// before one exists. Exactly one is active at a time, enforced on the server by
/// a partial unique index — the app asks for a year to be activated and reads
/// back which one won, rather than deciding for itself.
class FiscalYear {
  const FiscalYear({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.startDateBs,
    this.endDateBs,
    this.isActive = false,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  /// Empty on a draft the form has built and the server has not seen yet.
  final String id;

  /// Unique. What the shop calls the year, not a date range.
  final String name;

  /// AD boundaries, as the epoch millis everything sorts and filters on.
  final int startDate;
  final int endDate;

  /// The BS strings the boundaries were entered as, kept for display.
  final String? startDateBs;
  final String? endDateBs;

  final bool isActive;

  final int createdAt;
  final int updatedAt;

  bool containsMs(int ms) => ms >= startDate && ms <= endDate;

  /// Whether this year covers today.
  ///
  /// A year that has ended stays selectable for back-dated entry, but filing
  /// *today's* bill under it is a mistake worth pointing out — that is exactly
  /// how a bill ends up in a year nobody thinks to look in.
  bool get isCurrent => containsMs(NepaliDate.todayMs());

  String get rangeLabel =>
      '${NepaliDate.format(startDateBs ?? NepaliDate.msToBs(startDate))}'
      ' — '
      '${NepaliDate.format(endDateBs ?? NepaliDate.msToBs(endDate))}';

  factory FiscalYear.fromJson(Map<String, dynamic> json) => FiscalYear(
        id: WireCodec.string(json['id']),
        name: WireCodec.string(json['name']),
        startDate: WireCodec.dateMs(json['startDate']) ?? 0,
        endDate: WireCodec.dateMs(json['endDate']) ?? 0,
        startDateBs: WireCodec.stringOrNull(json['startDateBs']),
        endDateBs: WireCodec.stringOrNull(json['endDateBs']),
        isActive: WireCodec.boolean(json['isActive']),
        createdAt: WireCodec.millis(json['createdAt'], fallback: 0),
        updatedAt: WireCodec.millis(json['updatedAt'], fallback: 0),
      );

  /// The body `POST /fiscal-years` and `PATCH /fiscal-years/:id` accept.
  ///
  /// Only what the server owns as a column: no id, and no timestamps. Sending
  /// those back would be the client claiming to know values it was given.
  Map<String, dynamic> toRequestBody() => {
        'name': name,
        'startDate': NepaliDate.toIsoDate(NepaliDate.fromMs(startDate)),
        'endDate': NepaliDate.toIsoDate(NepaliDate.fromMs(endDate)),
        'startDateBs': startDateBs,
        'endDateBs': endDateBs,
        'isActive': isActive,
      };

  FiscalYear copyWith({
    String? name,
    int? startDate,
    int? endDate,
    String? startDateBs,
    String? endDateBs,
    bool? isActive,
  }) =>
      FiscalYear(
        id: id,
        name: name ?? this.name,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        startDateBs: startDateBs ?? this.startDateBs,
        endDateBs: endDateBs ?? this.endDateBs,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
