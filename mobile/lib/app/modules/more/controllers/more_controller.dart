import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/sync_service.dart';

/// The More tab.
class MoreController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();

  late final Rx<ThemeMode> themeMode = _storage.themeMode.obs;

  /// Whether there is a sync service to report on at all. The app runs
  /// perfectly well local-only, and a status chip in that state would be
  /// reporting on something the user has not switched on.
  bool get syncAvailable => Get.isRegistered<SyncService>();

  /// Applies the theme immediately and remembers it.
  ///
  /// `Get.changeThemeMode` rather than a rebuild of the root widget: the choice
  /// has to take effect on this screen, under the user's finger, not on the
  /// next app launch.
  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    _storage.themeMode = mode;
    Get.changeThemeMode(mode);
  }

  Future<void> signOut() async {
    final confirmed = await ConfirmDialog.show(
      title: 'Sign out?',
      message: 'Anything not yet synced stays on this device and will go up '
          'the next time you sign in.',
      confirmLabel: 'Sign out',
      isDestructive: true,
    );
    if (!confirmed) return;

    await AuthService.to.signOut();
  }
}
