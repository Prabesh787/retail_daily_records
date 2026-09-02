import '../../../core/constants/db_constants.dart';
import '../../enums/sync_status.dart';

/// Base for every entity that can be created offline and reconciled later.
///
/// Three fields do the real work:
/// * [id] is a UUID generated on the device, never a server auto-increment.
///   A bill created offline is immediately addressable, and its items can
///   reference it before it has ever touched the network.
/// * [updatedAt] is the last-write-wins tiebreaker during a merge.
/// * [isDeleted] makes deletions a soft flag, so a tombstone can travel to the
///   other clients. A hard `DELETE` would simply be invisible to them.
abstract class SyncableModel {
  const SyncableModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
    this.deviceId,
  });

  final String id;
  final int createdAt;
  final int updatedAt;
  final bool isDeleted;
  final SyncStatus syncStatus;
  final String? deviceId;

  /// The local SQLite row. Subclasses spread [syncMap] into their own map.
  Map<String, dynamic> toMap();

  /// The payload sent to the backend. Deliberately separate from [toMap] so a
  /// local-only column never leaks onto the wire — the DTOs own that mapping.
  Map<String, dynamic> toJson();

  Map<String, dynamic> get syncMap => {
        SyncColumns.id: id,
        SyncColumns.createdAt: createdAt,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.isDeleted: isDeleted ? 1 : 0,
        SyncColumns.syncStatus: syncStatus.code,
        SyncColumns.deviceId: deviceId,
      };

  /// The sync metadata every wire payload carries, spread into [toJson] the way
  /// [syncMap] is spread into [toMap].
  ///
  /// These four keys are snake_case while the domain fields beside them are
  /// camelCase, which looks inconsistent and is deliberate on both counts: the
  /// domain fields match the serializers the backend already has, so its `/sync`
  /// endpoints can reuse them unchanged, while `updated_at` and `device_id` are
  /// read straight off a pulled row by [SyncEngine]. Renaming either half means
  /// changing code on the other side of the network for no gain.
  ///
  /// `sync_status` is absent on purpose — it is this device's private opinion
  /// about a row, not a fact about the row.
  Map<String, dynamic> get syncJson => {
        'created_at': createdAt,
        'updated_at': updatedAt,
        'is_deleted': isDeleted,
        'device_id': deviceId,
      };

  static String idOf(Map<String, dynamic> map) =>
      map[SyncColumns.id] as String;
  static int createdAtOf(Map<String, dynamic> map) =>
      (map[SyncColumns.createdAt] as int?) ?? 0;
  static int updatedAtOf(Map<String, dynamic> map) =>
      (map[SyncColumns.updatedAt] as int?) ?? 0;
  static bool isDeletedOf(Map<String, dynamic> map) =>
      (map[SyncColumns.isDeleted] as int?) == 1;
  static SyncStatus syncStatusOf(Map<String, dynamic> map) =>
      SyncStatus.fromCode(map[SyncColumns.syncStatus] as int?);
  static String? deviceIdOf(Map<String, dynamic> map) =>
      map[SyncColumns.deviceId] as String?;

  /// Tolerant number read — SQLite hands back an int for a whole number stored
  /// in a REAL column, and JSON from the backend may do the same.
  static double toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int toInt(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
