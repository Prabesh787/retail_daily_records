import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../data/enums/sync_status.dart';
import '../data/providers/remote/sync_api.dart';
import '../data/sync/conflict_resolver.dart';
import '../data/sync/entity_syncer.dart';
import '../data/sync/sync_engine.dart';
import '../data/sync/sync_models.dart';
import '../data/sync/sync_state.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'storage_service.dart';

/// Owns the sync engine and decides when it runs.
///
/// Triggers, in order of usefulness:
///   * the offline -> online edge (the shop's wifi came back),
///   * app resume,
///   * the user pulling to refresh or tapping "Sync now",
///   * a slow periodic timer as a backstop.
///
/// Never on every write — a busy counter would then hammer the server once per
/// keystroke-sized change instead of sending one batch.
class SyncService extends GetxService with WidgetsBindingObserver {
  static SyncService get to => Get.find();

  late final SyncEngine _engine;
  late final DatabaseService _db;
  late final StorageService _storage;
  late final ConnectivityService _connectivity;
  late final SyncApi _api;

  final Rx<SyncState> state = const SyncState().obs;

  Timer? _periodic;
  StreamSubscription<void>? _reconnectSub;

  static const Duration periodicInterval = Duration(minutes: 15);

  Future<SyncService> init() async {
    _db = Get.find<DatabaseService>();
    _storage = Get.find<StorageService>();
    _connectivity = Get.find<ConnectivityService>();
    _api = Get.find<SyncApi>();

    _engine = SyncEngine(
      api: _api,
      queue: _db.syncQueue,
      syncers: buildSyncers(_db.db),
      cursors: _storage,
      resolver: ConflictResolver(deviceId: _storage.deviceId),
    );

    await refreshCounts();

    _reconnectSub = _connectivity.onReconnected.listen((_) => syncNow());
    _periodic = Timer.periodic(periodicInterval, (_) => syncNow());
    WidgetsBinding.instance.addObserver(this);

    return this;
  }

  bool get isEnabled => _storage.syncEnabled && _api.isConfigured;

  /// Runs a full cycle. Safe to call from anywhere — it no-ops when sync is
  /// off, offline, or already running, so callers never need to check first.
  Future<SyncReport> syncNow({bool force = false}) async {
    if (!isEnabled) {
      state.value = state.value.copyWith(phase: SyncPhase.disabled);
      return const SyncReport(error: 'Sync is disabled');
    }
    if (!force && !_connectivity.isOnline.value) {
      state.value = state.value.copyWith(phase: SyncPhase.offline);
      return const SyncReport(error: 'Offline');
    }
    if (_engine.isRunning) {
      return const SyncReport(error: 'Already syncing');
    }

    state.value = state.value.copyWith(
      phase: SyncPhase.syncing,
      clearError: true,
    );

    final report = await _engine.sync();
    await refreshCounts();

    state.value = state.value.copyWith(
      phase: report.isSuccess ? SyncPhase.idle : SyncPhase.failed,
      lastSyncedAt: _storage.lastSyncedAt,
      error: report.error,
      clearError: report.isSuccess,
    );
    return report;
  }

  /// Re-reads the outbox so the chip's pending count is accurate after a
  /// local write. Cheap — two indexed COUNT queries.
  Future<void> refreshCounts() async {
    final pending = await _db.syncQueue.pendingCount();
    final failed = await _db.syncQueue.failedCount();
    state.value = state.value.copyWith(
      pendingCount: pending,
      failedCount: failed,
      lastSyncedAt: _storage.lastSyncedAt,
      phase: _phaseFor(pending, failed),
    );
  }

  SyncPhase _phaseFor(int pending, int failed) {
    if (!isEnabled) return SyncPhase.disabled;
    if (state.value.isSyncing) return SyncPhase.syncing;
    if (!_connectivity.isOnline.value) return SyncPhase.offline;
    if (failed > 0) return SyncPhase.failed;
    return SyncPhase.idle;
  }

  /// User-initiated retry: clears the retry counters so rows that had given up
  /// are attempted again.
  Future<SyncReport> retryFailed() async {
    await _db.syncQueue.resetRetries();
    return syncNow(force: true);
  }

  /// Full re-pull from scratch, e.g. after restoring on a new device.
  Future<SyncReport> resyncFromScratch() async {
    await _storage.clearCursors();
    return syncNow(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncNow();
    }
  }

  @override
  void onClose() {
    _periodic?.cancel();
    _reconnectSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
