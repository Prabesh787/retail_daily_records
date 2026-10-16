import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../core/constants/entities.dart';
import '../core/utils/currency_formatter.dart';

/// The little that lives on the device.
///
/// The shop's records are on the server; what stays here is the session and the
/// handful of preferences that belong to this phone rather than to the
/// business — the theme, the currency symbol on a bill.
///
/// A [GetxService] rather than a controller because it must outlive every route
/// — `Get.delete()` on a route change must never take the theme with it.
class StorageService extends GetxService {
  late final GetStorage _box;

  static StorageService get to => Get.find();

  Future<StorageService> init() async {
    await GetStorage.init();
    _box = GetStorage();
    CurrencyFormatter.symbol = currencySymbol;
    return this;
  }

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

  /// For keys owned by another service that extends this one rather than
  /// opening its own box — one store means one `clearAll()` clears everything.
  String? readString(String key) => _box.read<String>(key);

  void writeString(String key, String? value) {
    if (value == null) {
      _box.remove(key);
    } else {
      _box.write(key, value);
    }
  }

  Future<void> clearAll() => _box.erase();
}
