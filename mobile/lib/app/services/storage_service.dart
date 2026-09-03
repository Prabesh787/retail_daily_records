import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/db_constants.dart';
import '../core/utils/currency_formatter.dart';
import '../data/sync/sync_engine.dart';

/// Key-value settings: shop profile, preferences, and the sync cursors.
///
/// A [GetxService] rather than a controller because it must outlive every route
/// — `Get.delete()` on a route change must never take the shop's currency with
/// it.
class StorageService extends GetxService implements SyncCursorStore {
  late final GetStorage _box;

  static StorageService get to => Get.find();

  Future<StorageService> init() async {
    await GetStorage.init();
    _box = GetStorage();
    CurrencyFormatter.symbol = currencySymbol;
    return this;
  }

  /// Stable per-install identifier, generated once.
  ///
  /// Sync needs this to recognise its own changes coming back on a pull —
  /// without it a device re-applies every row it just pushed, and an edit made
  /// locally can be overwritten by its own echo.
  String get deviceId {
    final existing = _box.read<String>(StorageKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = const Uuid().v4();
    _box.write(StorageKeys.deviceId, fresh);
    return fresh;
  }

  // ---- Shop profile -------------------------------------------------------

  String get shopName => _box.read<String>(StorageKeys.shopName) ?? 'My Shop';
  set shopName(String value) => _box.write(StorageKeys.shopName, value);

  String? get shopPhone => _box.read<String>(StorageKeys.shopPhone);
  set shopPhone(String? value) => _box.write(StorageKeys.shopPhone, value);

  String? get shopAddress => _box.read<String>(StorageKeys.shopAddress);
  set shopAddress(String? value) => _box.write(StorageKeys.shopAddress, value);

  String get currencySymbol =>
      _box.read<String>(StorageKeys.currencySymbol) ?? 'Rs.';
  set currencySymbol(String value) {
    _box.write(StorageKeys.currencySymbol, value);
    CurrencyFormatter.symbol = value;
  }

  /// Light, dark, or follow the phone.
  ///
  /// Stored as the mode's name rather than a bool, because "dark: false" cannot
  /// tell apart *chose light* from *never chose* — and those two want different
  /// behaviour when the phone switches to dark at sunset.
  ///
  /// Reads tolerate the old boolean this replaced, so an existing install keeps
  /// the preference it already had instead of silently reverting to system.
  ThemeMode get themeMode {
    final raw = _box.read<dynamic>(StorageKeys.themeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' || true => ThemeMode.dark,
      false => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  set themeMode(ThemeMode value) =>
      _box.write(StorageKeys.themeMode, value.name);

  // ---- Sync state ---------------------------------------------------------

  /// Whether the user has turned sync off. Off means the app is local-only and
  /// the UI says so plainly instead of showing a permanent "pending".
  ///
  /// Defaults to on, because a build that has a server address was made to
  /// reach it — [SyncService] still checks that separately, so a build without
  /// one is local-only whatever this says.
  bool get syncEnabled => _box.read<bool>(StorageKeys.syncEnabled) ?? true;
  set syncEnabled(bool value) => _box.write(StorageKeys.syncEnabled, value);

  @override
  int? get lastSyncedAt => _box.read<int>(StorageKeys.lastSyncedAt);
  @override
  set lastSyncedAt(int? value) =>
      _box.write(StorageKeys.lastSyncedAt, value);

  /// Per-entity pull cursor. Opaque to the app — whatever the server returned
  /// last time is handed straight back on the next pull.
  @override
  String? cursorFor(String entity) =>
      _box.read<String>(StorageKeys.cursor(entity));

  @override
  void setCursor(String entity, String? cursor) {
    if (cursor == null) return;
    _box.write(StorageKeys.cursor(entity), cursor);
  }

  // ---- Generic access -----------------------------------------------------

  /// For keys owned by another service that extends this one rather than
  /// opening its own box — one store means one `erase()` clears everything.
  String? readString(String key) => _box.read<String>(key);

  void writeString(String key, String? value) {
    if (value == null) {
      _box.remove(key);
    } else {
      _box.write(key, value);
    }
  }

  /// Forces the next sync to re-pull everything from scratch.
  Future<void> clearCursors() async {
    for (final entity in DbTables.syncable) {
      await _box.remove(StorageKeys.cursor(entity));
    }
    await _box.remove(StorageKeys.lastSyncedAt);
  }

  Future<void> clearAll() => _box.erase();
}
