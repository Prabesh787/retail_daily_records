/// What to do with a row that arrived from the server.
enum ConflictOutcome {
  /// No local copy, or the server's is newer — write it in.
  applyRemote,

  /// Our copy is newer, or this row is our own change echoing back.
  keepLocal,

  /// Our copy is newer *and* still queued — leave the outbox entry alone so
  /// the next push overwrites the server.
  keepLocalAndRepush,
}

/// Last-write-wins by `updated_at`, with two guards that matter in practice.
///
/// Bills and payments are append-only in this app — a mistake is voided and
/// re-issued rather than edited — so genuine conflicts are confined to master
/// data (a party's phone number, an item's price). For those, newest wins is
/// both correct enough and predictable, which beats a merge dialog a shopkeeper
/// would have to reason about mid-sale.
class ConflictResolver {
  const ConflictResolver({required this.deviceId});

  /// This device's id, used to recognise our own writes coming back.
  final String deviceId;

  ConflictOutcome resolve({
    required int? localUpdatedAt,
    required int remoteUpdatedAt,
    required bool localIsPending,
    String? remoteDeviceId,
  }) {
    // Our own change echoing back off the server. Applying it would be
    // harmless when nothing has moved, but destructive if the user edited the
    // row again while the push was in flight.
    if (remoteDeviceId != null && remoteDeviceId == deviceId) {
      return localIsPending ? ConflictOutcome.keepLocal : ConflictOutcome.applyRemote;
    }

    // Never seen locally: an insert from the web app or another device.
    if (localUpdatedAt == null) return ConflictOutcome.applyRemote;

    if (remoteUpdatedAt > localUpdatedAt) return ConflictOutcome.applyRemote;

    // Equal timestamps mean the same version; nothing to do either way.
    if (remoteUpdatedAt == localUpdatedAt) return ConflictOutcome.keepLocal;

    return localIsPending
        ? ConflictOutcome.keepLocalAndRepush
        : ConflictOutcome.keepLocal;
  }
}
