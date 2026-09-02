import '../../core/constants/db_constants.dart';
import '../../core/utils/nepali_date.dart';
import '../enums/sync_status.dart';
import 'base/syncable_model.dart';

/// A Nepali fiscal year, e.g. `2082/83`.
///
/// Every purchase, payment and sale belongs to one, so nothing can be recorded
/// before one exists. Exactly one is active at a time — on the server that is
/// enforced by a partial unique index; here the repository enforces it by
/// clearing the flag on the others inside the same transaction.
class FiscalYear extends SyncableModel {
  const FiscalYear({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.startDateBs,
    this.endDateBs,
    this.isActive = false,
    super.isDeleted,
    super.syncStatus,
    super.deviceId,
  });

  /// Unique. What the shop calls the year, not a date range.
  final String name;

  /// AD boundaries, as the epoch millis everything sorts and filters on.
  final int startDate;
  final int endDate;

  /// The BS strings the boundaries were entered as, kept for display.
  final String? startDateBs;
  final String? endDateBs;

  final bool isActive;

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

  @override
  Map<String, dynamic> toMap() => {
        ...syncMap,
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'start_date_bs': startDateBs,
        'end_date_bs': endDateBs,
        'is_active': isActive ? 1 : 0,
      };

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startDate': NepaliDate.toIsoDate(NepaliDate.fromMs(startDate)),
        'endDate': NepaliDate.toIsoDate(NepaliDate.fromMs(endDate)),
        'startDateBs': startDateBs,
        'endDateBs': endDateBs,
        'isActive': isActive,
        ...syncJson,
      };

  factory FiscalYear.fromMap(Map<String, dynamic> map) => FiscalYear(
        id: SyncableModel.idOf(map),
        createdAt: SyncableModel.createdAtOf(map),
        updatedAt: SyncableModel.updatedAtOf(map),
        isDeleted: SyncableModel.isDeletedOf(map),
        syncStatus: SyncableModel.syncStatusOf(map),
        deviceId: SyncableModel.deviceIdOf(map),
        name: (map['name'] as String?) ?? '',
        startDate: SyncableModel.toInt(map['start_date']),
        endDate: SyncableModel.toInt(map['end_date']),
        startDateBs: map['start_date_bs'] as String?,
        endDateBs: map['end_date_bs'] as String?,
        isActive: (map['is_active'] as int?) == 1,
      );

  FiscalYear copyWith({
    String? name,
    int? startDate,
    int? endDate,
    String? startDateBs,
    String? endDateBs,
    bool? isActive,
    int? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    String? deviceId,
  }) =>
      FiscalYear(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        name: name ?? this.name,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        startDateBs: startDateBs ?? this.startDateBs,
        endDateBs: endDateBs ?? this.endDateBs,
        isActive: isActive ?? this.isActive,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        deviceId: deviceId ?? this.deviceId,
      );

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS ${DbTables.fiscalYear} (
      id            TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      start_date    INTEGER NOT NULL,
      end_date      INTEGER NOT NULL,
      start_date_bs TEXT,
      end_date_bs   TEXT,
      is_active     INTEGER NOT NULL DEFAULT 0,
      ${SyncColumns.definition}
    )
  ''';

  /// Year names are unique, mirroring the server. Partial, because a tombstone
  /// should not reserve a name.
  static const String uniqueNameSql = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_fiscal_year_name
      ON ${DbTables.fiscalYear} (name)
      WHERE is_deleted = 0
  ''';
}
