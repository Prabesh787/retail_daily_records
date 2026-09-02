import '../../core/utils/date_utils.dart';
import '../enums/sync_status.dart';

/// What the sync chip renders.
///
/// Shown deliberately and plainly: a shopkeeper trusts an app that says
/// "3 bills pending" over one that syncs silently and loses a day of sales
/// without ever mentioning it.
class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncedAt,
    this.error,
  });

  final SyncPhase phase;
  final int pendingCount;
  final int failedCount;
  final int? lastSyncedAt;
  final String? error;

  bool get hasPending => pendingCount > 0;
  bool get hasFailures => failedCount > 0;
  bool get isSyncing => phase == SyncPhase.syncing;

  String get label => switch (phase) {
        SyncPhase.disabled => 'Local only',
        SyncPhase.syncing => 'Syncing...',
        SyncPhase.offline =>
          hasPending ? 'Offline - $pendingCount pending' : 'Offline',
        SyncPhase.failed => 'Sync failed',
        SyncPhase.idle => hasPending
            ? '$pendingCount pending'
            : 'Synced ${AppDateUtils.relative(lastSyncedAt)}',
      };

  SyncState copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? failedCount,
    int? lastSyncedAt,
    String? error,
    bool clearError = false,
  }) =>
      SyncState(
        phase: phase ?? this.phase,
        pendingCount: pendingCount ?? this.pendingCount,
        failedCount: failedCount ?? this.failedCount,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        error: clearError ? null : (error ?? this.error),
      );
}
