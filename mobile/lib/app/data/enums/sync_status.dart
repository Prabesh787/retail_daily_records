/// Per-row sync state, stored as an int so it can be indexed and counted in SQL
/// (`SELECT COUNT(*) WHERE sync_status = 0` powers the "3 pending" chip).
enum SyncStatus {
  pending(0, 'Pending'),
  synced(1, 'Synced'),
  failed(2, 'Failed');

  const SyncStatus(this.code, this.label);

  final int code;
  final String label;

  static SyncStatus fromCode(int? code) => SyncStatus.values.firstWhere(
        (e) => e.code == code,
        orElse: () => SyncStatus.pending,
      );
}

/// What the server should do with a queued row.
enum SyncOperationType {
  upsert('upsert'),
  delete('delete');

  const SyncOperationType(this.value);

  final String value;

  static SyncOperationType fromValue(String? value) =>
      SyncOperationType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => SyncOperationType.upsert,
      );
}

/// Engine-level state, surfaced by the dashboard sync chip.
enum SyncPhase { idle, syncing, offline, failed, disabled }
